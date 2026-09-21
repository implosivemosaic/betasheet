defmodule ClimbOntarioWeb.Plugs.CanonicalHost do
  @moduledoc """
  One public address. Requests for any other host (www, the old fly.dev name)
  get a permanent redirect to the same path on the canonical host. Health
  checks are exempt because Fly calls them by machine address.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/healthz"} = conn, _), do: conn

  def call(conn, opts) do
    canonical = opts[:host] || ClimbOntarioWeb.Endpoint.config(:url)[:host]

    if is_binary(canonical) and canonical not in ["localhost", conn.host] and
         Application.get_env(:climb_ontario, :canonical_redirect, true) do
      location = "https://#{canonical}#{conn.request_path}#{query(conn)}"

      conn
      |> put_resp_header("location", location)
      |> send_resp(301, "")
      |> halt()
    else
      conn
    end
  end

  defp query(%{query_string: ""}), do: ""
  defp query(%{query_string: q}), do: "?" <> q
end
