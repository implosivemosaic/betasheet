defmodule ClimbOntarioWeb.ClassSchedule do
  @moduledoc """
  The per-class view of a listing that bundles several classes, each on its own
  schedule (School of Rock: "Pebble 6–7 Tuesday", "Rock Club 8–10 Tuesday", …).
  Pure: describes what is on file, never infers dates or times.
  """
  alias ClimbOntario.Catalogue.{Listing, Occurrence}
  alias ClimbOntarioWeb.{Format, ListingCalendar}

  @weekdays ~w(Mondays Tuesdays Wednesdays Thursdays Fridays Saturdays Sundays)

  @doc "Several named classes under one listing."
  def bundled?(%{cohorts: [_, _ | _]}), do: true
  def bundled?(_), do: false

  @doc """
  What to call a class on the page, from its name and the listing's kind:
  "Monday class", "Tuesday 4:30 pm class", "Ages 8–10 · Saturday class",
  "Heat 1", "Fri Oct 9, 2026 camp". Names state the distinguishing fact; a
  " — " suffix carries the weekday only where two classes would otherwise
  share a name.
  """
  def label(listing, name) do
    {fact, day} =
      case String.split(name, " — ", parts: 2) do
        [fact, day] -> {fact, day}
        [fact] -> {fact, nil}
      end

    fact =
      case Date.from_iso8601(fact) do
        {:ok, date} -> Format.date_with_year(date)
        _ -> clock_times(fact)
      end

    # A level- or format-named class still shows its age band when one is on file.
    ages =
      case Enum.find(Map.get(listing, :classes) || [], &(&1.name == name)) do
        %{ages: a} when is_binary(a) and a != "" -> if String.contains?(fact, a), do: nil, else: ages_text(a)
        _ -> nil
      end

    fact = Enum.join(Enum.reject([fact, ages], &is_nil/1), " · ")

    noun =
      case listing.kind do
        "class" -> " class"
        "camp" -> " camp"
        "social" -> " session"
        _ -> ""
      end

    [fact, day && clock_times(day)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ") |> Kernel.<>(noun)
  end

  defp ages_text(a), do: if(a =~ ~r/^\d/, do: "Ages #{a}", else: String.capitalize(a))

  # "Tuesday 16:30" -> "Tuesday 4:30 pm"
  defp clock_times(text) do
    Regex.replace(~r/\b(\d{1,2}):(\d{2})\b/, text, fn _, h, m ->
      Format.time(Time.new!(String.to_integer(h), String.to_integer(m), 0))
    end)
  end

  @doc "One entry per class, in the listing's own order."
  def classes(listing, today) do
    common_place = Listing.display_location(listing)
    timezone = Format.common_timezone(listing)

    Enum.map(listing.cohorts, fn name ->
      sessions =
        listing.occurrences
        |> Enum.filter(&(&1.cohort == name))
        |> Enum.sort_by(&Occurrence.sort_key/1)

      next = Enum.find(sessions, &(Date.compare(&1.date, today) != :lt))

      rows =
        Enum.map(sessions, fn o ->
          place = Listing.location(listing, o)

          text =
            [
              Format.date_with_year(o.date),
              if(timezone,
                do: Format.time_range(o.start_time, o.end_time) || "Time not announced",
                else: Format.time_line(o)
              ),
              if(place != common_place, do: Format.venue_line(place)),
              if(place != common_place, do: place.street_address)
            ]
            |> Enum.reject(&(&1 in [nil, ""]))
            |> Enum.join(" · ")

          state =
            cond do
              Date.compare(o.date, today) == :lt -> :past
              o == next -> :next
              true -> :future
            end

          %{text: text, state: state, occurrence: o}
        end)

      %{
        name: name,
        label: label(listing, name),
        sessions: sessions,
        rows: rows,
        next: next,
        pattern: pattern(sessions),
        exportable: ListingCalendar.sessions(listing, name) != []
      }
    end)
  end

  @doc "\"Tuesdays · 4–5:15 pm · 10 sessions · Sep 8 – Nov 23\" from the sessions on file."
  def pattern([]), do: "Dates and times not confirmed"

  def pattern(sessions) do
    days = sessions |> Enum.map(&Date.day_of_week(&1.date)) |> Enum.uniq() |> Enum.sort()
    times = sessions |> Enum.map(&{&1.start_time, &1.end_time}) |> Enum.uniq()
    first = List.first(sessions).date
    last = List.last(sessions).date

    [
      case days do
        [d] -> Enum.at(@weekdays, d - 1)
        [a, b] -> "#{Enum.at(@weekdays, a - 1)} and #{Enum.at(@weekdays, b - 1)}"
        _ -> "Various days"
      end,
      case times do
        [{nil, _}] -> "Time not announced"
        [{s, e}] -> Format.time_range(s, e)
        _ -> "Times vary"
      end,
      "#{length(sessions)} #{if length(sessions) == 1, do: "session", else: "sessions"}",
      if(first == last, do: Format.date(first), else: "#{Format.short_date(first)} – #{Format.short_date(last)}")
    ]
    |> Enum.join(" · ")
  end
end
