defmodule Mix.Tasks.Climb.Stats do
  @shortdoc "Print the built-in page counter: mix climb.stats [days]"
  @moduledoc "Daily views and uniques, top pages, top searches and referrers from the page_views table."
  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")
    days = args |> List.first() |> then(&if(&1, do: String.to_integer(&1), else: 7))
    s = ClimbOntario.Stats.summary(days)
    Mix.shell().info("Since #{s.since} (#{days} days)\n\nDay         Views  Uniques")
    for {day, views, uniques} <- s.daily, do: Mix.shell().info("#{day}  #{pad(views)}  #{pad(uniques)}")
    section("Top pages", s.paths)
    section("Top searches", s.queries)
    section("Referrers", s.referrers)
  end

  defp section(title, rows) do
    Mix.shell().info("\n#{title}")
    for {key, n} <- rows, do: Mix.shell().info("#{pad(n)}  #{key}")
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(5)
end
