defmodule ClimbOntario.Catalogue.Keyword do
  @moduledoc "Pure candidate matching: every query word must match a title, description or venue word. Never ranks results."
  alias ClimbOntario.Catalogue.Listing

  def matches?(_, nil), do: true

  def matches?(listing, query) do
    places = [
      Listing.location(listing) | Enum.map(listing.occurrences, &Listing.location(listing, &1))
    ]

    words =
      [listing.title, listing.summary, listing.venue.name | Enum.map(places, & &1.name)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> tokens()

    Enum.all?(tokens(query), fn term -> Enum.any?(words, &match_word?(term, &1)) end)
  end

  def tokens(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.split(~r/[^\p{L}\p{N}]+/u, trim: true)
  end

  defp match_word?(term, word) do
    String.starts_with?(word, term) or
      (String.length(term) >= 4 and abs(String.length(term) - String.length(word)) <= 1 and
         one_edit?(String.graphemes(term), String.graphemes(word)))
  end

  defp one_edit?([a | as], [a | bs]), do: one_edit?(as, bs)
  defp one_edit?(a, b) when a == b, do: true
  defp one_edit?([_ | as] = a, [_ | bs] = b), do: as == bs or as == b or a == bs
  defp one_edit?([], [_]), do: true
  defp one_edit?([_], []), do: true
  defp one_edit?(_, _), do: false
end
