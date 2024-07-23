defmodule Platform.Balancer do
  use GenServer
  alias Phoenix.PubSub
  # alias Platform.BalancerCluster
  alias Platform.BalancerRecord

  def table_name(), do: :balancer
  def pubsub_topic(), do: "balancer_update"

  def dump(), do: BalancerRecord.dump(table_name())

  def join(id, model) do
    BalancerRecord.insert(
      table_name(),
      [%BalancerRecord{id: id, model: model, status: :free, node: Node.self()}]
    )
  end

  def leave(id) do
    BalancerRecord.delete(table_name(), id)
  end

  def lock(id) do
    case BalancerRecord.lookup(table_name(), id) do
      %BalancerRecord{status: :free} ->
        BalancerRecord.update(table_name(), id, :status, :lock)

      _ ->
        false
    end
  end

  def free(id) do
    BalancerRecord.update(table_name(), id, :status, :free)
  end

  def get_worker(model) do
    case BalancerRecord.select(table_name(), model: model, status: :free) do
      [_ | _] = workers ->
        %BalancerRecord{id: id} = Enum.random(workers)

        case lock(id) do
          true -> {:ok, id}
          false -> {:error, :lock_failed}
        end

      [] ->
        # BalancerCluster.get_worker(model)
        {:error, :no_workers}
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(
      table_name(),
      [
        :set,
        :public,
        :named_table,
        {:write_concurrency, :auto},
        {:read_concurrency, true}
      ]
    )

    send(self(), :workers_update)

    {:ok, []}
  end

  def terminate(_reason, _state) do
    :ets.delete(table_name())

    :ok
  end

  def handle_info(:workers_update, state) do
    PubSub.broadcast(
      Platform.PubSub,
      pubsub_topic(),
      {
        :workers_update,
        BalancerRecord.dump(table_name()),
        Node.self()
      }
    )

    Process.send_after(
      self(),
      :workers_update,
      Application.fetch_env!(:platform, :workers_update_interval)
    )

    {:noreply, state}
  end
end
