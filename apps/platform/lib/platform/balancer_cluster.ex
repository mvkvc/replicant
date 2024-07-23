defmodule Platform.BalancerCluster do
  use GenServer
  alias Phoenix.PubSub
  alias Platform.Balancer
  alias Platform.BalancerRecord

  def table_name(), do: :balancer_cluster
  def dump(), do: BalancerRecord.dump(table_name())

  def get_worker(model) do
    case BalancerRecord.select(table_name(), model: model, status: :free) do
      [_ | _] = workers ->
        %BalancerRecord{id: id, node: node} = Enum.random(workers)

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
      table_name(),
      [
        :set,
        :public,
        :named_table,
        {:write_concurrency, :auto},
        {:read_concurrency, true}
      ]
    )

    PubSub.subscribe(Platform.PubSub, Balancer.pubsub_topic())
    :net_kernel.monitor_nodes(true)

    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    :ets.delete(table_name())

    :ok
  end

  @impl true
  def handle_info({:workers_update, workers, node}, state) do
    BalancerRecord.select_delete(table_name(), node_eq: node)
    BalancerRecord.insert(table_name(), workers)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, _node}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    BalancerRecord.select_delete(table_name(), node: node)

    {:noreply, state}
  end
end
