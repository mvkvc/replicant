defmodule Platform.AMQPPublisher do
  use AMQP
  use GenServer
  alias Platform.PartitionSupervisorAMQPPublisher

  # @amqp_channel :req_chann
  @amqp_exchange "exchange_inference"

  def publish(payload, opt \\ []) do
    n_partitions = Application.fetch_env!(:platform, :amqp_pub_partitions)
    key = :rand.uniform(n_partitions)

    GenServer.call(
      {
        :via,
        PartitionSupervisor,
        {PartitionSupervisorAMQPPublisher, key}
      },
      {:publish, payload, opt}
    )
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_opts) do
    # {:ok, chan} = AMQP.Application.get_channel(@amqp_channel)
    {:ok, chan} = AMQP.Application.get_channel()

    {:ok, %{chan: chan}}
  end

  @impl true
  def handle_call({:publish, payload, opt}, _from, %{chan: chan} = state) do
    {:reply, publish_queue(chan, payload, opt), state}
  end

  def publish_queue(chan, request, opt \\ []) do
    retry_attempt = Keyword.get(opt, :retry_attempt, 0)
    retry_expire = Keyword.get(opt, :retry_expire, 0)

    headers = [
      {"x-retry-attempt", :long, retry_attempt},
      {"x-retry-expire", :long, retry_expire}
    ]

    with {:ok, payload} <- Jason.encode(request),
         #  {:ok, model} <- Map.fetch(request.params, "model"),
         model when is_binary(model) <- get_in(request, ["params", "model"]),
         :ok <-
           AMQP.Basic.publish(
             chan,
             @amqp_exchange,
             model,
             payload,
             headers: headers,
             mandatory: true
           ) do
      :ok
    else
      :error -> {:error, :model_not_found}
      {:error, reason} -> {:error, reason}
    end
  end
end
