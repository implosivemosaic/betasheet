defmodule ClimbOntario.Stats do
  @moduledoc """
  Built-in page counter: views land in the `page_views` table in SQLite.

  Privacy by construction: no cookies, no third parties, and no raw address or
  user agent on disk. Each view carries a visitor hash of the day, the address
  and the user agent salted with the app secret, so daily uniques can be
  counted but nothing links one day's visitor to the next.
  """
  import Ecto.Query
  alias ClimbOntario.{Clock, Repo}
  alias ClimbOntario.Stats.PageView

  @bots ~r/bot|crawl|spider|slurp|preview|fetch|monitor|headless|facebookexternalhit|whatsapp|telegram|curl|wget|python-requests/i

  @doc "Record a view. Never raises; failures are logged and dropped."
  def track(%{path: path} = view) when is_binary(path) do
    if bot?(view[:user_agent]) do
      :skipped
    else
      today = Clock.today()

      attrs = %{
        day: today,
        path: String.slice(path, 0, 200),
        query: view[:query] && String.slice(view[:query], 0, 200),
        referrer: referrer_host(view[:referrer]),
        visitor: visitor(today, view[:ip], view[:user_agent]),
        inserted_at: DateTime.utc_now(:second)
      }

      # Synchronous on purpose: one tiny SQLite insert, and it stays inside the
      # caller's connection ownership (which also keeps tests sandboxed).
      try do
        Repo.insert!(struct(PageView, attrs), log: false)
        :ok
      rescue
        e ->
          require Logger
          Logger.warning("stats: #{Exception.message(e)}")
          :error
      end
    end
  end

  def track(_), do: :skipped

  @doc "Views, uniques, top paths and top searches for the last `days` days."
  def summary(days \\ 7) do
    since = Date.add(Clock.today(), -(days - 1))

    daily =
      Repo.all(
        from v in PageView,
          where: v.day >= ^since,
          group_by: v.day,
          order_by: v.day,
          select: {v.day, count(v.id), count(v.visitor, :distinct)}
      )

    top = fn field, limit ->
      Repo.all(
        from v in PageView,
          where: v.day >= ^since and not is_nil(field(v, ^field)),
          group_by: field(v, ^field),
          order_by: [desc: count(v.id)],
          limit: ^limit,
          select: {field(v, ^field), count(v.id)}
      )
    end

    %{since: since, daily: daily, paths: top.(:path, 15), queries: top.(:query, 15), referrers: top.(:referrer, 10)}
  end

  defp bot?(nil), do: false
  defp bot?(ua), do: Regex.match?(@bots, ua)

  defp visitor(day, ip, ua) do
    secret = Application.get_env(:climb_ontario, ClimbOntarioWeb.Endpoint)[:secret_key_base] || ""

    :crypto.hash(:sha256, [secret, Date.to_iso8601(day), to_string(ip), to_string(ua)])
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp referrer_host(nil), do: nil

  defp referrer_host(ref) do
    case URI.parse(ref) do
      %URI{host: host} when is_binary(host) -> String.slice(host, 0, 100)
      _ -> nil
    end
  end
end
