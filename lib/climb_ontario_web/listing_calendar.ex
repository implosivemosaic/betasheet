defmodule ClimbOntarioWeb.ListingCalendar do
  @moduledoc """
  A whole listing's confirmed sessions as one calendar, two ways: an .ics
  with one event per session (Apple, Outlook, subscriptions), and a prefilled
  Google Calendar link that carries a repeat rule when the sessions are regular.
  Nothing is inferred: only sessions with a confirmed date, time and zone appear.
  """
  alias ClimbOntario.Catalogue.Listing
  alias ClimbOntarioWeb.SessionCalendar

  @doc "Exportable sessions, optionally for one cohort, in order."
  def sessions(listing, cohort \\ nil) do
    listing.occurrences
    |> Enum.filter(&(is_nil(cohort) or &1.cohort == cohort))
    |> Enum.filter(&SessionCalendar.exportable?/1)
    |> Enum.sort_by(&{Date.to_gregorian_days(&1.date), &1.start_time})
  end

  @doc "Cohorts that have something to export; [nil] when the listing has no named groups."
  def groups(listing) do
    case listing.cohorts do
      [] -> if sessions(listing) == [], do: [], else: [nil]
      cohorts -> Enum.filter(cohorts, &(sessions(listing, &1) != []))
    end
  end

  def render(listing, cohort, page_url, now) do
    case sessions(listing, cohort) do
      [] ->
        :error

      sessions ->
        lines =
          Enum.map(sessions, fn s ->
            {:ok, lines} = SessionCalendar.event_lines(listing, s, page_url, now)
            lines
          end)

        name = Enum.join(Enum.reject([listing.title, cohort], &is_nil/1), " · ")
        {:ok, SessionCalendar.document(lines, "Listing", name)}
    end
  end

  @doc """
  Prefilled Google Calendar link for the sessions. Regular runs (same weekday,
  same times, evenly spaced) become one repeating event; anything else is the
  first session with the remaining dates spelled out in the description.
  """
  def google_url(listing, cohort, page_url) do
    case sessions(listing, cohort) do
      [] ->
        nil

      [first | _] = sessions ->
        {:ok, start, finish} = SessionCalendar.local_instants(first)
        finish = finish || DateTime.add(start, 3600, :second, Tzdata.TimeZoneDatabase)
        place = Listing.location(listing, first)
        title = Enum.join(Enum.reject([listing.title, cohort], &is_nil/1), " · ")

        location =
          Enum.join(Enum.reject([place.name, place.street_address, place.city], &is_nil/1), ", ")

        rule = rrule(sessions)

        details =
          [
            "Original event: #{listing.link}",
            "Details and updates: #{page_url}",
            if(is_nil(rule) and length(sessions) > 1,
              do: "All dates: " <> Enum.map_join(sessions, ", ", &Calendar.strftime(&1.date, "%b %-d"))
            )
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.join("\n")

        params =
          [
            {"action", "TEMPLATE"},
            {"text", title},
            {"dates", "#{local(start)}/#{local(finish)}"},
            {"ctz", first.timezone},
            {"location", location},
            {"details", details},
            rule && {"recur", "RRULE:" <> rule}
          ]
          |> Enum.reject(&is_nil/1)

        "https://calendar.google.com/calendar/render?" <> URI.encode_query(params)
    end
  end

  @doc "FREQ=WEEKLY rule when the sessions repeat evenly at the same time and place, else nil."
  def rrule([_]), do: nil

  def rrule(sessions) do
    gaps =
      sessions
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> Date.diff(b.date, a.date) end)

    same = fn f -> sessions |> Enum.map(f) |> Enum.uniq() |> length() == 1 end

    with [gap] <- Enum.uniq(gaps),
         true <- gap > 0 and rem(gap, 7) == 0 and gap <= 28,
         true <- same.(&{&1.start_time, &1.end_time, &1.timezone}),
         true <- same.(&{&1.location_kind, &1.venue_id, &1.offsite_address}) do
      interval = if div(gap, 7) == 1, do: "", else: ";INTERVAL=#{div(gap, 7)}"
      "FREQ=WEEKLY#{interval};COUNT=#{length(sessions)}"
    else
      _ -> nil
    end
  end

  defp local(dt), do: Calendar.strftime(dt, "%Y%m%dT%H%M%S")
end
