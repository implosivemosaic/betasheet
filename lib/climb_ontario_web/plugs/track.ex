defmodule ClimbOntarioWeb.Plugs.Track do
  @moduledoc "Counts plain HTML page loads (event pages). LiveView pages count themselves once connected."
  import Plug.Conn
  alias ClimbOntario.Stats

  def init(opts), do: opts

  def call(%Plug.Conn{method: "GET"} = conn, _opts) do
    register_before_send(conn, fn conn ->
      if conn.status == 200 and conn.private[:phoenix_live_view] == nil do
        Stats.track(%{
          path: conn.request_path,
          query: nil,
          referrer: first_header(conn, "referer"),
          ip: client_ip(conn),
          user_agent: first_header(conn, "user-agent")
        })
      end

      conn
    end)
  end

  def call(conn, _opts), do: conn

  def client_ip(conn) do
    first_header(conn, "fly-client-ip") ||
      (first_header(conn, "x-forwarded-for") || "")
      |> String.split(",")
      |> List.first()
      |> String.trim()
      |> case do
        "" -> conn.remote_ip |> :inet.ntoa() |> to_string()
        ip -> ip
      end
  end

  defp first_header(conn, name), do: conn |> get_req_header(name) |> List.first()
end
