defmodule Platform.AMQPConsumer do
  use AMQP
  use GenServer
  alias Platform.AMQPPublisher
  alias Platform.Balancer
  alias PlatformWeb.Endpoint

  # @amqp_channel :req_chann
  @amqp_exchange "exchange_inference"
  @worker_topic "request"

  def inference_topic(worker_id) do
    "inference:#{worker_id}"
  end

  def start_link([model: _model] = opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  def init(model: model) do
    # {:ok, chan} = AMQP.Application.get_channel(@amqp_channel)
    {:ok, chan} = AMQP.Application.get_channel()
    {:ok, _queue_info} = setup_queue(chan, model)

    prefetch_count = Application.fetch_env!(:platform, :amqp_prefetch_count)
    :ok = Basic.qos(chan, prefetch_count: prefetch_count, global: true)
    {:ok, _consumer_tag} = Basic.consume(chan, model)

    {:ok, chan}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info(
        {:basic_deliver, payload,
         %{
           headers: headers,
           routing_key: model,
           delivery_tag: delivery_tag,
           redelivered: _redelivered
         }},
        chan
      ) do
    Basic.ack(chan, delivery_tag)

    request = Jason.decode!(payload)

    with {:ok, worker_id} <- Balancer.get_worker(model),
         {:ok, request_id} <- Map.fetch(request, "id"),
         {:ok, params} <- Map.fetch(request, "params") do
      #  :ok <- Basic.ack(chan, delivery_tag) do
      push(worker_id, request_id, params)
    else
      _ ->
        #  Basic.nack(chan, delivery_tag, requeue: true)
        spawn(fn -> handle_retry(chan, delivery_tag, request, headers) end)
    end

    {:noreply, chan}
  end

  # TODO: Remove retry attempt logic and have fixed sleep before republishing
  defp handle_retry(_chan, _delivery_tag, payload, headers) do
    # IO.inspect({payload, headers}, label: "RETRY")

    retry_attempt = Enum.find_value(headers, 0, fn {key, _type, value} ->
      if key == "x-retry-attempt", do: value
    end)

    retry_expire = Enum.find_value(headers, 0, fn {key, _type, value} ->
      if key == "x-retry-expire", do: value
    end)

    current_time = DateTime.to_unix(DateTime.utc_now())

    IO.inspect({retry_expire, current_time, retry_expire > current_time}, label: "RETRY TIME")

    if retry_expire > current_time do
      # Process.sleep(Application.fetch_env!(:platform, :amqp_retry_delay))
      Process.sleep(Application.fetch_env!(:platform, :amqp_retry_delay) * retry_attempt)

      IO.inspect({payload, retry_attempt+1, retry_expire}, label: "RETRYING")

      AMQPPublisher.publish(
        payload,
        retry_attempt: retry_attempt + 1,
        retry_expire: retry_expire
      )
    else
      IO.inspect({payload, retry_attempt, retry_expire}, label: "RETRY FAIL")
    end
  end

  def setup_queue(chan, key) do
    with {:ok, queue_info} <-
           Queue.declare(chan, key,
             auto_delete: true,
             arguments: [
               {"x-message-ttl", :long, Application.fetch_env!(:platform, :request_timeout)}
             ]
           ),
         :ok <- Exchange.topic(chan, @amqp_exchange),
         :ok <- Queue.bind(chan, key, @amqp_exchange, routing_key: key) do
      {:ok, queue_info}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp push(worker_id, request_id, params) do
    Endpoint.broadcast(
      inference_topic(worker_id),
      @worker_topic,
      %{id: request_id, params: params}
    )
  end
end
