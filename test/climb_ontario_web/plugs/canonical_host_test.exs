defmodule ClimbOntarioWeb.Plugs.CanonicalHostTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn
  alias ClimbOntarioWeb.Plugs.CanonicalHost

  setup do
    Application.put_env(:climb_ontario, :canonical_redirect, true)
    on_exit(fn -> Application.put_env(:climb_ontario, :canonical_redirect, false) end)
  end

  test "other hosts redirect permanently to the canonical host, keeping path and query; health checks pass" do
    canonical = "betasheet.ca"
    opts = [host: canonical]
    conn = conn(:get, "/e/1-x?a=1") |> Map.put(:host, "www.example.org") |> CanonicalHost.call(opts)
    assert conn.status == 301
    assert get_resp_header(conn, "location") == ["https://#{canonical}/e/1-x?a=1"]
    assert conn.halted

    refute (conn(:get, "/") |> Map.put(:host, canonical) |> CanonicalHost.call(opts)).halted
    refute (conn(:get, "/healthz") |> Map.put(:host, "www.example.org") |> CanonicalHost.call(opts)).halted
  end
end
