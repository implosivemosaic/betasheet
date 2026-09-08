defmodule Mix.Tasks.Catalogue.Build do
  @shortdoc "Rebuild the public catalogue from the research database (read-only source)"
  @moduledoc "mix catalogue.build — reads RESEARCH_DB read-only and upserts venues + listings."
  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.config")
    {:ok, _} = Application.ensure_all_started(:climb_ontario)
    result = ClimbOntario.Catalogue.Builder.run()
    Mix.shell().info("Catalogue built: #{inspect(result)}")
  end
end
