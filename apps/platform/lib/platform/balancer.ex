defmodule Platform.Balancer do
  use GenServer
  import Ex2ms
  alias Phoenix.PubSub
  alias Platform.BalancerCluster

  @table_name :balancer

  def table_name(), do: @table_name

  def pubsub_topic(), do: "balancer_update"

  def dump() do
    :ets.tab2list(@table_name)
  end

  defp update_status(id, status) do
    :ets.update_element(@table_name, id, {3, status})
  end

  def join(id, model) do
    :ets.insert(@table_name, {id, model, :free})
  end

  def leave(id) do
    :ets.delete(@table_name, id)
  end

  def lock(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, _model, :free}] ->
        update_status(id, :lock)

      _ ->
        false
    end
  end

  def free(id) do
    update_status(id, :free)
  end

  def get_worker(model) do
    match_spec =
      fun do
        {_, ^model, :free} = worker -> worker
      end

    case :ets.select(@table_name, match_spec) do
      [_ | _] = workers ->
        {id, _model, :free} = Enum.random(workers)

        case lock(id) do
          true -> {:ok, id}
          false -> {:error, :lock_failed}
        end

      [] ->
        BalancerCluster.get_worker(model)
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(
      @table_name,
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true}
      ]
    )

    Process.send(
      self(),
      :agg,
      []
    )

    {:ok, []}
  end

  def terminate(_reason, _state) do
    :ets.delete(@table_name)

    :ok
  end

  def handle_info(:agg, state) do
    workers =
      @table_name
      |> :ets.tab2list()
      |> Enum.map(fn {id, model, status} ->
        {id, model, status, Node.self()}
      end)

    if workers != state do
      PubSub.broadcast(
        Platform.PubSub,
        pubsub_topic(),
        {:agg, workers, Node.self()}
      )
    end

    Process.send_after(
      self(),
      :agg,
      Application.fetch_env!(:platform, :worker_agg_interval)
    )

    {:noreply, workers}
  end
end
