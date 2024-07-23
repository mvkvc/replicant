defmodule PlatformWeb.WorkersLive do
  use PlatformWeb, :live_view
  alias Phoenix.PubSub
  alias Platform.Balancer
  # alias Platform.BalancerCluster

  @workers_display_ops ["model", "node"]
  @workers_display_ops_default "model"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col space-y-2">
      <h1 class="text-2xl font-semibold">Workers</h1>
      <div class="flex flex-row space-x-2 items-center">
        <p>Display by:</p>
        <%= for display_op <- @workers_display_ops do %>
          <button
            phx-click="update_op"
            phx-value-new-op={display_op}
            class={"btn btn-secondary" <> if display_op == @workers_display_op, do: " btn-active", else: ""}
          >
            <%= display_op %>
          </button>
        <% end %>
      </div>
      <%= if @workers_display && length(Map.keys(@workers_display)) > 0 do %>
        <%= for key <- Map.keys(@workers_display) do %>
          <div class="node-group mb-4 space-y-2">
            <h3 class="text-lg font-bold"><%= key %></h3>
            <p>Total workers: <%= length(Map.get(@workers_display, key)) %></p>
            <div class="flex flex-wrap">
              <%= for worker <- Map.get(@workers_display, key) do %>
                <div
                  class={"w-8 h-8 bg-gray-300 aspect-w-1 aspect-h-1 " <> "#{status_color(worker.status)} mr-2 mb-2"}
                  title={
                      "id: #{worker.id}\nmodel: #{worker.model}\nstatus: #{worker.status}\nnode: #{worker.node}"}
                >
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <p>No workers available.</p>
      <% end %>
    </div>
    """
  end

  defp status_base(), do: ""
  defp status_color(:free), do: status_base() <> "bg-green-400"
  defp status_color(:lock), do: status_base() <> "bg-red-400"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Platform.PubSub, Balancer.pubsub_topic())
      :net_kernel.monitor_nodes(true)
    end

    # workers_dump = BalancerCluster.dump()
    workers_dump = Balancer.dump()
    workers = Enum.group_by(workers_dump, fn worker -> worker.node end)
    workers_display = transform_display(workers, @workers_display_ops_default)

    {:ok,
     socket
     |> assign(workers: workers)
     |> assign(workers_display_ops: @workers_display_ops)
     |> assign(workers_display_op: @workers_display_ops_default)
     |> assign(workers_display: workers_display)}
  end

  @impl true
  def handle_info({:nodeup, _node}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:nodedown, node}, socket) do
    new_workers = Map.delete(socket.assigns.workers, node)

    {:noreply, assign(socket, workers: new_workers)}
  end

  @impl true
  def handle_info({:workers_update, node_workers, node}, socket) do
    workers = socket.assigns.workers
    workers_display_op = socket.assigns.workers_display_op

    new_workers = Map.put(workers, node, node_workers)
    new_workers_display = transform_display(new_workers, workers_display_op)

    {:noreply,
     socket
     |> assign(workers: new_workers)
     |> assign(workers_display: new_workers_display)}
  end

  @impl true
  def handle_event("update_op", %{"new-op" => new_display_op}, socket) do
    workers = socket.assigns.workers
    new_workers_display = transform_display(workers, new_display_op)

    {:noreply,
     socket
     |> assign(workers_display_op: new_display_op)
     |> assign(workers_display: new_workers_display)}
  end

  def get_workers_by_model(workers) do
    workers_list =
      workers
      |> Map.values()
      |> List.flatten()

    case workers_list do
      [] -> %{}
      list -> Enum.group_by(list, fn worker -> worker.model end)
    end
  end

  def transform_display(workers, display_op) when display_op in @workers_display_ops do
    case display_op do
      "node" -> workers
      "model" -> get_workers_by_model(workers)
    end
  end
end
