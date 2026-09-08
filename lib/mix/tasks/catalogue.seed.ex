defmodule Mix.Tasks.Catalogue.Seed do
  @shortdoc "Seed venues and unpublished listing skeletons from the research database (read-only source)"
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:climb_ontario)
    Mix.shell().info("Seeded: #{inspect(ClimbOntario.Catalogue.Seed.run())}")
  end
end
