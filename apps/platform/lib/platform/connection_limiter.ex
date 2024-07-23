defmodule Platform.ConnectionLimiter do
  def cache_name(), do: :connection_limiter

  defp update_cache(nil, time_now), do: {0, time_now}
  defp update_cache({count, last_time}, _time_now), do: {count, last_time}

  def check(key) do
    reset_ms = Application.fetch_env!(:platform, :conn_limit_reset)
    limit_per_second = Application.fetch_env!(:platform, :conn_limit_ps)
    time_now = NaiveDateTime.utc_now()

    case Cachex.get_and_update(cache_name(), key, &update_cache(&1, time_now)) do
      {:commit, {count, last_time}} ->
        time_diff_ms = NaiveDateTime.diff(time_now, last_time, :millisecond)

        cond do
          time_diff_ms > reset_ms ->
            Cachex.put(cache_name(), key, {1, time_now})
            :ok

          count < limit_per_second ->
            Cachex.incr(cache_name(), key)
            :ok

          true ->
            {:error, :rate_limit}
        end
    end
  end
end
