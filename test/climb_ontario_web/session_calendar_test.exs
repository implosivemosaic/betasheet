defmodule ClimbOntarioWeb.SessionCalendarTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Catalogue.{Listing, Occurrence, Venue}
  alias ClimbOntarioWeb.SessionCalendar

  @now ~U[2026-09-17 12:34:56Z]
  @page "https://climb.example/e/1-test"

  defp listing do
    %Listing{
      id: 1,
      title: "Climb, play; learn\\repeat\nNew line " <> String.duplicate("é", 50),
      location_kind: "venue",
      venue: %Venue{name: "Organizer", city: "Aurora"},
      link: "https://organizer.example/event?a=1&b=2"
    }
  end

  defp session do
    %Occurrence{
      id: 2,
      listing_id: 1,
      date: ~D[2026-09-20],
      start_time: ~T[08:00:00],
      end_time: ~T[10:00:00],
      timezone: "America/Toronto",
      location_kind: "offsite",
      offsite_name: "Actual, Park",
      offsite_city: "Toronto",
      offsite_address: "123 Park St"
    }
  end

  defp properties(ics) do
    ics
    |> String.replace("\r\n ", "")
    |> String.split("\r\n", trim: true)
    |> Enum.map(&List.to_tuple(String.split(&1, ":", parts: 2)))
    |> Map.new()
  end

  test "valid UTC times, escaping, UTF-8 line folding, actual location, stable UID and both links" do
    assert {:ok, ics} = SessionCalendar.render(listing(), session(), @page, @now)
    p = properties(ics)
    assert p["DTSTART"] == "20260920T120000Z"
    assert p["DTEND"] == "20260920T140000Z"
    assert p["DTSTAMP"] == "20260917T123456Z"
    assert p["UID"] == "listing-1-session-2@climb-ontario"

    assert p["SUMMARY"] ==
             "Climb\\, play\\; learn\\\\repeat\\nNew line " <> String.duplicate("é", 50)

    assert p["LOCATION"] == "Actual\\, Park\\, 123 Park St\\, Toronto"
    assert p["DESCRIPTION"] =~ "Original event: #{listing().link}\\nBeta Sheet: #{@page}"
    assert p["URL"] == listing().link
    assert length(Regex.scan(~r/BEGIN:VEVENT/, ics)) == 1
    refute ics =~ "RRULE"
    assert String.ends_with?(ics, "END:VCALENDAR\r\n")

    for line <- String.split(ics, "\r\n"),
        do: assert(String.valid?(line) and byte_size(line) <= 75)
  end

  test "winter offset differs; absent end time exports no invented duration" do
    s = %{session() | date: ~D[2026-12-20], end_time: nil, cohort: "Teens"}
    assert {:ok, ics} = SessionCalendar.render(listing(), s, @page, @now)
    assert properties(ics)["DTSTART"] == "20261220T130000Z"
    assert String.ends_with?(properties(ics)["SUMMARY"], " · Teens")
    refute ics =~ "DTEND"
    refute ics =~ "DURATION"
    refute ics =~ "VALUE=DATE"
  end

  test "unknown, invalid, ambiguous and nonexistent wall times never export a guessed instant" do
    for changes <- [
          %{start_time: nil},
          %{timezone: nil},
          %{timezone: "Unknown/Zone"},
          %{date: ~D[2026-11-01], start_time: ~T[01:30:00], end_time: nil},
          %{date: ~D[2026-03-08], start_time: ~T[02:30:00], end_time: nil}
        ] do
      s = struct(session(), changes)
      refute SessionCalendar.exportable?(s)
      assert SessionCalendar.render(listing(), s, @page, @now) == :error
    end

    refute SessionCalendar.exportable?(nil)
  end
end
