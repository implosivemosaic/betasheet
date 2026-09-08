defmodule ClimbOntario.Geo.Normalize do
  @moduledoc "Lookup key for place text: lowercase, accents stripped, non-alphanumerics removed."
  def key(nil), do: ""

  def key(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/^(city|town|township|municipality|village) of /u, "")
    |> String.replace(~r/[^a-z0-9]/u, "")
  end
end
