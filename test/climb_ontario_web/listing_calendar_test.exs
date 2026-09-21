defmodule ClimbOntarioWeb.ListingCalendarTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import ClimbOntario.Fixtures
  import Phoenix.LiveViewTest, only: [render_component: 2]
  alias ClimbOntarioWeb.ListingCalendar

  @page "https://climb.example/e/1-test"

  defp course(sessions, attrs \\ %{}) do
    listing!(
      venue!(%{slug: "v#{System.unique_integer([:positive])}"}),
      Map.merge(
        %{
          title: "Pebbles — Fall",
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31]
        },
        attrs
      ),
      sessions
    )
  end

  defp at(date, cohort \\ nil),
    do: %{date: date, cohort: cohort, start_time: ~T[09:00:00], end_time: ~T[10:30:00], timezone: "America/Toronto"}

  test "weekly runs become one repeating Google event; the .ics carries every session" do
    l = course([at(~D[2026-09-13]), at(~D[2026-09-20]), at(~D[2026-09-27]), at(~D[2026-10-04])])

    url = ListingCalendar.google_url(l, nil, @page)
    q = url |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    assert q["dates"] == "20260913T090000/20260913T103000"
    assert q["ctz"] == "America/Toronto"
    assert q["recur"] == "RRULE:FREQ=WEEKLY;COUNT=4"
    assert q["text"] == "Pebbles — Fall"
    assert q["location"] =~ "Reach Indoor Climbing"
    assert q["details"] =~ @page
    refute q["details"] =~ "All dates"

    {:ok, ics} = ListingCalendar.render(l, nil, @page, ~U[2026-09-01 00:00:00Z])
    assert length(Regex.scan(~r/BEGIN:VEVENT/, ics)) == 4
    assert ics =~ "X-WR-CALNAME:Pebbles — Fall"
    assert ics =~ "DTSTART:20261004T130000Z"
  end

  test "fortnightly runs get an interval; irregular dates fall back to a list" do
    l = course([at(~D[2026-09-13]), at(~D[2026-09-27]), at(~D[2026-10-11])])
    assert ListingCalendar.rrule(ListingCalendar.sessions(l)) == "FREQ=WEEKLY;INTERVAL=2;COUNT=3"

    l = course([at(~D[2026-09-13]), at(~D[2026-09-27]), at(~D[2026-10-04])])
    q = ListingCalendar.google_url(l, nil, @page) |> URI.parse() |> Map.get(:query) |> URI.decode_query()
    refute Map.has_key?(q, "recur")
    assert q["details"] =~ "All dates: Sep 13, Sep 27, Oct 4"
  end

  test "named groups export separately and only exportable sessions count" do
    l =
      course(
        [at(~D[2026-09-13], "Kids"), at(~D[2026-09-20], "Kids"), at(~D[2026-09-14], "Teens"), %{date: ~D[2026-09-21], cohort: "Teens"}],
        %{cohorts: ["Kids", "Teens"], bundled_by: "age", classes: [%{name: "Kids", ages: "6–12"}, %{name: "Teens", ages: "13–17"}]}
      )

    assert ListingCalendar.groups(l) == ["Kids", "Teens"]
    assert length(ListingCalendar.sessions(l, "Teens")) == 1
    assert ListingCalendar.google_url(l, "Kids", @page) =~ "RRULE%3AFREQ%3DWEEKLY%3BCOUNT%3D2"
    assert ListingCalendar.google_url(l, "Kids", @page) =~ "Pebbles+%E2%80%94+Fall+%C2%B7+Kids"
    {:ok, ics} = ListingCalendar.render(l, "Teens", @page, ~U[2026-09-01 00:00:00Z])
    assert length(Regex.scan(~r/BEGIN:VEVENT/, ics)) == 1

    bare = course([%{date: ~D[2026-09-13]}])
    assert ListingCalendar.groups(bare) == []
    assert ListingCalendar.google_url(bare, nil, @page) == nil
  end

  test "the listing .ics route serves inline and the event page offers all three links" do
    l = course([at(~D[2026-09-13]), at(~D[2026-09-20])])
    conn = get(Phoenix.ConnTest.build_conn(), "/e/#{l.id}/calendar.ics")
    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") |> hd() =~ "text/calendar"
    assert Plug.Conn.get_resp_header(conn, "content-disposition") |> hd() =~ "inline"
    assert length(Regex.scan(~r/BEGIN:VEVENT/, conn.resp_body)) == 2
    assert get(Phoenix.ConnTest.build_conn(), "/e/#{l.id}/calendar.ics?cohort=Nope").status == 404

    html = get(Phoenix.ConnTest.build_conn(), "/e/#{ClimbOntario.Catalogue.Listing.slug(l)}") |> Phoenix.ConnTest.html_response(200)
    assert html =~ "Add to your calendar"
    assert html =~ "calendar.google.com/calendar/render?action=TEMPLATE"
    assert html =~ "/e/#{l.id}/calendar.ics"
    assert html =~ "webcal://"
  end

  test "a bundle of classes gets one schedule block per class, labelled from its name, with its own calendar links" do
    l =
      course(
        [
          at(~D[2026-09-13], "Ages 6–8"),
          at(~D[2026-09-20], "Ages 6–8"),
          %{date: ~D[2026-09-15], cohort: "Ages 13–17 — Tuesday", start_time: ~T[16:00:00], end_time: ~T[17:15:00], timezone: "America/Toronto"},
          %{date: ~D[2026-09-22], cohort: "Ages 13–17 — Tuesday", start_time: ~T[16:00:00], end_time: ~T[17:15:00], timezone: "America/Toronto"}
        ],
        %{
          cohorts: ["Ages 6–8", "Ages 13–17 — Tuesday", "Adults"],
          bundled_by: "age",
          classes: [%{name: "Ages 6–8", ages: "6–8"}, %{name: "Ages 13–17 — Tuesday", ages: "13–17"}, %{name: "Adults", ages: "18+"}]
        }
      )

    html = get(Phoenix.ConnTest.build_conn(), "/e/#{ClimbOntario.Catalogue.Listing.slug(l)}") |> Phoenix.ConnTest.html_response(200)
    assert html =~ ~s(href="#classes")
    assert html =~ "3 classes"
    assert html =~ "Ages 6–8 class"
    assert html =~ "Ages 13–17 · Tuesday class"
    assert html =~ "Adults · Ages 18+ class"
    assert html =~ "Sundays · 9–10:30 am · 2 sessions · Sep 13 – Sep 20"
    assert html =~ "Tuesdays · 4–5:15 pm · 2 sessions · Sep 15 – Sep 22"
    assert html =~ "Dates and times not confirmed"
    refute html =~ "each on its own schedule"
    refute html =~ "Find yours"
    refute html =~ "Known schedule"
    refute html =~ "Add to your calendar"
    refute html =~ "Session 1 of"
    assert length(Regex.scan(~r/calendar\.google\.com\/calendar\/render/, html)) == 2
    assert html =~ "calendar.ics?cohort=Ages+13%E2%80%9317+%E2%80%94+Tuesday"

    card = render_component(&ClimbOntarioWeb.ListingComponents.listing_card/1, listing: l, today: ~D[2026-09-10])
    assert card =~ "3 classes"
    assert card =~ "Ages 6–8 class"
    refute card =~ " of ~"
  end

  test "class labels come from the name and the listing kind" do
    alias ClimbOntarioWeb.ClassSchedule
    assert ClassSchedule.label(%{kind: "class"}, "Monday") == "Monday class"
    assert ClassSchedule.label(%{kind: "class"}, "Tuesday 16:30") == "Tuesday 4:30 pm class"
    assert ClassSchedule.label(%{kind: "class"}, "SOHR 1.0 · Ages 6–8 — Wednesday 17:15") == "SOHR 1.0 · Ages 6–8 · Wednesday 5:15 pm class"
    assert ClassSchedule.label(%{kind: "competition"}, "Heat 1") == "Heat 1"
    level = %{kind: "class", classes: [%{name: "SOHR 1.0 — Monday", ages: "6–8"}, %{name: "U13", ages: "born 2013–2014"}]}
    assert ClassSchedule.label(level, "SOHR 1.0 — Monday") == "SOHR 1.0 · Ages 6–8 · Monday class"
    assert ClassSchedule.label(level, "U13") == "U13 · Born 2013–2014 class"
    assert ClassSchedule.label(%{kind: "camp"}, "2026-10-09") == "Fri Oct 9, 2026 camp"
    assert ClassSchedule.label(%{kind: "social"}, "Saturday") == "Saturday session"
  end
end
