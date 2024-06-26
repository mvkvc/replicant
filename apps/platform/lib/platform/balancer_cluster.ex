defmodule Platform.BalancerCluster do
  use GenServer
  import Ex2ms
  alias Phoenix.PubSub
  alias Platform.Balancer

  @table_name :balancer_cluster

  def table_name(), do: @table_name

  def dump() do
    :ets.tab2list(@table_name)
  end

  def get_worker(model) do
    node_self = Node.self()

    match_spec =
      fun do
        {_id, ^model, :free, node} = worker when node != ^node_self -> worker
      end

    case :ets.select(@table_name, match_spec) do
      [_ | _] = workers ->
        {id, ^model, :free, node} = Enum.random(workers)

        case :rpc.call(node, Balancer, :lock, [id]) do
          true -> {:ok, id}
          _ -> {:error, :lock_failed}
        end

      [] ->
        {:error, :no_workers}
    end
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
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

    PubSub.subscribe(Platform.PubSub, Balancer.pubsub_topic())
    :net_kernel.monitor_nodes(true)

    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ets.delete(@table_name)

    :ok
  end

  @impl true
  def handle_info({:agg, workers, node}, state) do
    if node != Node.self() do
      :ets.insert(@table_name, workers)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, _node}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    match_spec =
      fun do
        {_, _, _, ^node} -> true
      end

    :ets.select_delete(@table_name, match_spec)

    {:noreply, state}
  end
end
