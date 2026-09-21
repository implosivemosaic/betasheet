defmodule ClimbOntarioWeb.HealthController do
  use ClimbOntarioWeb, :controller

  def show(conn, _) do
    Ecto.Adapters.SQL.query!(ClimbOntario.Repo, "SELECT 1 FROM listings LIMIT 1", [], log: false)
    text(conn, "ok")
  end
end
