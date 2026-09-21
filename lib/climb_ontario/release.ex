defmodule ClimbOntario.Release do
  @moduledoc "Release boot migration on the SQLite volume; never seeds or imports data."

  def migrate do
    Application.load(:climb_ontario)

    {:ok, _, _} =
      Ecto.Migrator.with_repo(ClimbOntario.Repo, fn repo ->
        Ecto.Migrator.run(repo, :up, all: true)
      end)
  end
end
