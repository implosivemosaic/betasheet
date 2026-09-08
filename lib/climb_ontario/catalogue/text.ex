defmodule ClimbOntario.Catalogue.Text do
  @moduledoc """
  Pure formatters that turn researcher notes into readable public copy.

  Research text often lost its spaces ("SixWednesdaysSeptember16,23,30"). These
  functions re-insert spacing conservatively and never touch proper-noun casing.
  """

  @doc "Re-space mangled prose. Safe for descriptions, notes, price and recurrence text."
  def unmangle(nil), do: nil

  def unmangle(text) do
    text
    |> String.replace(~r/[  ]/u, " ")
    |> String.replace(~r/([a-z]{2,})([A-Z][a-z])/u, "\\1 \\2")
    |> respace_digits()
    |> String.replace(~r/,(?=[^\s\d])/u, ", ")
    |> String.replace(~r/,(?=\d)(?!\d{3}\b)/u, ", ")
    |> String.replace(~r/\.(?=[A-Z][a-z])/u, ". ")
    |> String.replace(~r/;(?=\S)/u, "; ")
    |> String.replace(~r/[ \t]+/u, " ")
    |> String.replace(~r/ ?\n ?/u, "\n")
    |> String.trim()
  end

  @doc "Re-space only letter/digit boundaries. Safe for titles (keeps RockHaus, McIntosh)."
  def respace_digits(nil), do: nil

  def respace_digits(text) do
    text
    |> String.replace(~r/([A-Za-z]{2,})(\d)/u, "\\1 \\2")
    |> String.replace(~r/(\d)([A-Z][a-z])/u, "\\1 \\2")
    |> String.replace(~r/(\d)([a-z]{2,})/u, "\\1 \\2")
    |> String.replace(~r/(\d)([A-Z]{2,})(?=\b)/u, "\\1 \\2")
  end

  @doc "First sentence or two of a description, capped near `max` characters."
  def summary(text, max \\ 200)
  def summary(nil, _max), do: ""

  def summary(text, max) do
    clean =
      text
      |> unmangle()
      |> String.split("\n", trim: true)
      |> Enum.reject(&looks_like_dump?/1)
      |> Enum.join(" ")

    sentences = Regex.split(~r/(?<=[.!?])\s+/u, clean)

    Enum.reduce_while(sentences, "", fn s, acc ->
      candidate = String.trim(acc <> " " <> s)

      cond do
        acc == "" and String.length(candidate) > max -> {:halt, truncate(candidate, max)}
        String.length(candidate) > max -> {:halt, acc}
        true -> {:cont, candidate}
      end
    end)
  end

  @doc "Compact price for a card: the first dollar amount, 'Free', or nil."
  def price_short(nil), do: nil

  def price_short(text) do
    cond do
      Regex.match?(~r/\bfree\b/iu, text) and not Regex.match?(~r/\$\s?\d/u, text) -> "Free"
      m = Regex.run(~r/(?:CAD\s?|\$)\s?(\d[\d,]*(?:\.\d{2})?)/u, text) -> "$" <> Enum.at(m, 1)
      true -> nil
    end
  end

  @doc "URL-safe slug from a title."
  def slugify(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, 70)
    |> String.trim("-")
  end

  defp truncate(text, max) do
    cut = String.slice(text, 0, max - 1)

    case String.split(cut, " ") do
      [_] -> cut <> "…"
      words -> Enum.join(Enum.drop(words, -1), " ") <> "…"
    end
  end

  # Source dumps like "Saturday, December 12, 20269:00 a.m." or address-only lines.
  defp looks_like_dump?(line) do
    Regex.match?(~r/^\s*(Saturday|Sunday|Monday|Tuesday|Wednesday|Thursday|Friday),/u, line) or
      Regex.match?(
        ~r/^\s*\d{1,4}\s+[A-Z][A-Za-z.]+\s+(St|Street|Ave|Avenue|Rd|Road|Dr|Drive|Blvd)/u,
        line
      ) or
      Regex.match?(~r/\d{1,2}:\d{2}\s*[ap]\.?m\.?\s*$/iu, line)
  end
end
