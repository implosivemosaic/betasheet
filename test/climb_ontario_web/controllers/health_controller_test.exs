defmodule ClimbOntarioWeb.HealthControllerTest do
  use ClimbOntarioWeb.ConnCase, async: false

  test "health check returns only minimal status", %{conn: conn} do
    assert conn |> get("/healthz") |> response(200) == "ok"
  end
end
