defmodule ClimbOntario.Catalogue.ResearchSource do
  @moduledoc """
  Read-only adapter over the research SQLite file. Opens with mode=ro and
  query_only so the research database can never be modified from here.
  """
  alias Exqlite.Sqlite3

  def path, do: Application.fetch_env!(:climb_ontario, :research_db)

  @doc "Returns %{gyms: [map], events: [map]} with events carrying their `sources` list."
  def load(db_path \\ path()) do
    {:ok, conn} = Sqlite3.open("file:#{db_path}?mode=ro", mode: :readonly)
    :ok = Sqlite3.execute(conn, "PRAGMA query_only = ON")

    try do
      gyms = rows(conn, "SELECT * FROM gyms ORDER BY id")
      events = rows(conn, "SELECT * FROM events ORDER BY id")
      sources = rows(conn, "SELECT event_id, platform, url FROM event_sources ORDER BY id")
      by_event = Enum.group_by(sources, & &1["event_id"])
      events = Enum.map(events, &Map.put(&1, "sources", Map.get(by_event, &1["id"], [])))
      %{gyms: gyms, events: events}
    after
      Sqlite3.close(conn)
    end
  end

  defp rows(conn, sql) do
    {:ok, stmt} = Sqlite3.prepare(conn, sql)
    {:ok, cols} = Sqlite3.columns(conn, stmt)
    {:ok, raw} = Sqlite3.fetch_all(conn, stmt)
    :ok = Sqlite3.release(conn, stmt)
    Enum.map(raw, &Map.new(Enum.zip(cols, &1)))
  end
end
