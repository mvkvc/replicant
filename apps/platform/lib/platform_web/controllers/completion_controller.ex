defmodule PlatformWeb.CompletionController do
  use PlatformWeb, :controller
  alias Ecto.Changeset
  alias Phoenix.PubSub
  alias Platform.AMQPPublisher
  alias Platform.API
  alias Platform.API.ParamsCompletion
  alias Platform.API.Request
  alias Platform.Balancer
  alias Platform.Model
  # alias PlatformWeb.Endpoint
  alias PlatformWeb.InferenceChannel

  # @worker_retry 500
  # @worker_timeout 30_000
  # @worker_topic "request"

  def new(conn, params) do
    request_attrs =
      %{
        id: Ecto.UUID.generate(),
        requester_id: conn.assigns.current_user.id,
        type: :completion,
        params: params,
        time_start: DateTime.utc_now()
      }

    retry_expire =
      DateTime.to_unix(DateTime.utc_now()) +
        round(Application.fetch_env!(:platform, :request_timeout) / 1_000)

    publish_attrs = request_attrs |> Jason.encode!() |> Jason.decode!()

    # IO.inspect(retry_expire, label: "PUBLISH EXPIRE")

    with %Changeset{valid?: true} <- Request.changeset(%Request{}, request_attrs),
         %Changeset{valid?: true} <- ParamsCompletion.changeset(%ParamsCompletion{}, params),
         :ok <-
           AMQPPublisher.publish(publish_attrs, retry_attempt: 0, retry_expire: retry_expire) do
      # send(self(), {:search_worker, request_attrs})
      # search_worker(conn, request_attrs)
      handle_request(conn, request_attrs)
    else
      %Changeset{valid?: false} = changeset ->
        error_changeset(conn, request_attrs, :new, changeset)

      {:error, reason} ->
        error(conn, request_attrs, :new, reason)
    end
  end

  # defp search_worker(conn, request_attrs, count \\ 0) do
  #   case Balancer.get_worker(request_attrs.params["model"]) do
  #     {:ok, client_id} ->
  #       PubSub.broadcast(
  #         Platform.PubSub,
  #         InferenceChannel.topic_channel(client_id),
  #         {:request, %{id: request_attrs.id, params: request_attrs.params}}
  #       )

  #       handle_request(conn, request_attrs)

  #     {:error, :no_workers} ->
  #       if count > round(@worker_timeout / @worker_retry) do
  #         error(conn, request_attrs, :search_worker, :timeout)
  #       else
  #         Process.sleep(@worker_retry)
  #         search_worker(conn, request_attrs, count + 1)
  #       end
  #   end
  # end

  # def handle_info({:search_worker, request_attrs}, conn) do
  #   IO.inspect(request_attrs, label: "SEARCH WORKER")

  #   case Balancer.get_worker(request_attrs.params["model"]) do
  #     {:ok, client_id} ->
  #       PubSub.broadcast(
  #         Platform.PubSub,
  #         InferenceChannel.topic_channel(client_id),
  #         InferenceChannel.topic_request(),
  #         %{id: request_attrs.id, params: request_attrs.params}
  #       )

  #     {:error, :no_workers} ->
  #       Process.send_after(self(), {:search_worker, request_attrs}, @worker_retry)
  #   end

  #   {:noreply, conn}
  # end

  defp handle_request(conn, request_attrs) do
    PubSub.subscribe(Platform.PubSub, "requests:" <> request_attrs.id)

    receive do
      {:result, result, worker_id, client_id} ->
        request_attrs =
          request_attrs
          |> Map.put(:status, "200")
          |> Map.put(:worker_id, worker_id)
          |> Map.put(:client_id, client_id)
          |> Map.put(:response, extract_text_result(result))

        success(conn, request_attrs, result)

      {:chunk_start, worker_id, client_id} ->
        request_attrs =
          request_attrs
          |> Map.put(:worker_id, worker_id)
          |> Map.put(:client_id, client_id)

        conn
        |> put_resp_header("connection", "keep-alive")
        |> put_resp_header("Content-Type", "text/event-stream; charset=utf-8")
        |> put_resp_header("Cache-Control", "no-cache")
        |> Plug.Conn.send_chunked(200)
        |> sse(request_attrs)

      {:error, reason, worker_id, client_id} ->
        request_attrs =
          request_attrs
          |> Map.put(:worker_id, worker_id)
          |> Map.put(:client_id, client_id)

        error(conn, request_attrs, :handle, reason)
    after
      Application.fetch_env!(:platform, :request_timeout) ->
        error(conn, request_attrs, :handle, :timeout)
    end
  end

  defp sse(conn, request_attrs, text_acc \\ "") do
    receive do
      {:chunk, chunk} ->
        text_acc = text_acc <> extract_text_chunk(chunk)

        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            sse(conn, request_attrs, text_acc)

          {:error, "closed"} ->
            request_attrs = Map.put(request_attrs, :response, text_acc)

            success_chunk(conn, request_attrs)

          {:error, reason} ->
            error_chunk(conn, request_attrs, :sse, reason)
        end

      :chunk_end ->
        request_attrs = Map.put(request_attrs, :response, text_acc)

        success_chunk(conn, request_attrs)

      {:chunk_error, reason} ->
        error_chunk(conn, request_attrs, :sse, reason)

      _unknown ->
        sse(conn, request_attrs, text_acc)
    after
      Application.fetch_env!(:platform, :request_timeout_chunk) ->
        error_chunk(conn, request_attrs, :sse, :timeout_chunk)
    end
  end

  defp success(conn, request_attrs, result) do
    handle_success(request_attrs)

    conn
    |> put_status(200)
    |> json(result)
  end

  defp success_chunk(conn, request_attrs) do
    handle_success(request_attrs)

    conn
  end

  defp error(conn, request_attrs, stage, reason) do
    handle_error(request_attrs, stage, reason)

    conn
    |> put_status(500)
    |> json(%{error: reason})
  end

  def error_chunk(conn, request_attrs, stage, reason) do
    handle_error(request_attrs, stage, reason)

    Plug.Conn.chunk(conn, format_error(reason))

    conn
  end

  defp error_changeset(conn, request_attrs, stage, %Changeset{errors: errors} = changeset) do
    handle_error(request_attrs, stage, errors)

    conn
    |> put_status(500)
    |> put_view(json: PlatformWeb.ChangesetJSON)
    |> render("error.json", changeset: changeset)
  end

  defp handle_error(request_attrs, _stage, reason) do
    Task.start(fn ->
      client_id = Map.get(request_attrs, :client_id)

      if client_id do
        publish_client(client_id, :disconnect)
      end

      # TODO: Add the error stage to the request body

      request_attrs
      |> Map.put(:status, "500")
      |> Map.put(:time_end, DateTime.utc_now())
      |> Map.put(:response, format_error(reason))
      |> API.create_request()
    end)
  end

  defp handle_success(request_attrs) do
    Task.start(fn ->
      client_id = Map.get(request_attrs, :client_id)
      if client_id, do: publish_client(client_id, :free)

      requester_id = request_attrs.requester_id
      worker_id = request_attrs.worker_id
      n_tokens = Model.count_tokens(request_attrs.response)
      reward = Model.calculate_reward(request_attrs.params["model"], n_tokens)

      request_attrs =
        request_attrs
        |> Map.put(:status, "200")
        |> Map.put(:tokens, n_tokens)
        |> Map.put(:reward, reward)
        |> Map.put(:time_end, DateTime.utc_now())

      request_attrs =
        with true <- requester_id != worker_id,
             {:ok, transaction} <-
               API.transfer_credits(reward, requester_id, worker_id) do
          topics = [
            "transactions:#{requester_id}",
            "transactions:#{worker_id}"
          ]

          Enum.each(topics, fn topic ->
            PubSub.broadcast(
              Platform.PubSub,
              topic,
              {:transaction, transaction}
            )
          end)
        else
          _ -> request_attrs
        end

      API.create_request(request_attrs)
    end)
  end

  defp publish_client(client_id, payload) do
    # Endpoint.broadcast("inference:" <> client_id, "disconnect", %{
    #   stage: stage,
    #   reason: reason
    # })
    PubSub.broadcast(
      Platform.PubSub,
      InferenceChannel.topic_channel(client_id),
      payload
    )
  end

  # https://pastebin.com/N3AnXqa5
  defp extract_text_result(result) do
    try do
      result
      |> Map.get("choices")
      |> List.first()
      |> get_in(["message", "content"])
    rescue
      _ -> ""
    end
  end

  # https://pastebin.com/z2sJxrMV
  defp extract_text_chunk(chunk) do
    chunk
    |> String.trim()
    |> String.split("data: ")
    |> Enum.reduce("", fn str, acc ->
      if str == "[DONE]" do
        acc
      else
        str_formatted =
          str
          |> String.trim()
          |> (fn s -> if String.starts_with?(s, "{\""), do: s, else: "{\"#{s}" end).()
          |> (fn s -> if String.ends_with?(s, "}"), do: s, else: "#{s}}" end).()

        case Jason.decode(str_formatted) do
          {:ok, decoded} ->
            text =
              try do
                decoded
                |> Map.get("choices", [])
                |> List.first()
                |> get_in(["delta", "content"])
              rescue
                _ -> ""
              end

            acc <> text

          {:error, _} ->
            acc
        end
      end
    end)
  end

  defp error_prefix(), do: "ERROR: "

  defp format_error(reason) when is_binary(reason), do: error_prefix() <> reason
  defp format_error(reason), do: error_prefix() <> inspect(reason)
end
