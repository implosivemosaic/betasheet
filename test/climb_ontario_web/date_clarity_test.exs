defmodule ClimbOntarioWeb.DateClarityTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  import Phoenix.LiveViewTest
  alias ClimbOntario.{Catalogue, Catalogue.Query}
  alias ClimbOntarioWeb.{Format, ListingComponents}

  @today ~D[2026-09-08]

  test "series stacks replace date-adjacent language, with no repeated date" do
    venue = venue!()

    for {kind, schedule, start} <- [
          {"class", "one_off", ~D[2026-09-10]},
          {"class", "course", ~D[2026-09-10]},
          {"class", "course", ~D[2026-09-01]},
          {"social", "recurring", nil},
          {"class", "recurring", nil}
        ] do
      l =
        listing!(
          venue,
          %{
            kind: kind,
            schedule_kind: schedule,
            start_date: start,
            end_date: if(schedule == "course", do: ~D[2026-10-01])
          },
          [~D[2026-09-10]]
        )

      html = render_component(&ListingComponents.listing_card/1, listing: l, today: @today)
      assert html =~ "series-card" == schedule in ~w(course recurring)
      assert length(Regex.scan(~r/data-date=/, html)) == 1

      for text <- [
            "Next session",
            "Next meetup",
            "In progress",
            "Starts",
            "confirmed session(s)"
          ] do
        refute html =~ text
      end
    end
  end

  test "filters keep qualifying date and chronological ordering without relabelling a later course session as Starts" do
    v = venue!()

    course =
      listing!(
        v,
        %{
          title: "Course",
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-10],
          end_date: ~D[2026-10-01]
        },
        [~D[2026-09-10], ~D[2026-09-17]]
      )

    event = listing!(v, %{title: "Event", start_date: ~D[2026-09-15]})

    assert Enum.map(Catalogue.search(Query.from_params(%{}, @today)).dated, & &1.id) == [
             course.id,
             event.id
           ]

    q = Query.from_params(%{"from" => "2026-09-14", "to" => "2026-09-20"}, @today)
    assert [e, c] = Catalogue.search(q).dated
    assert [e.id, c.id] == [event.id, course.id]
    assert c.discovery_date == ~D[2026-09-17]
    assert Format.card_date(c, @today) == c.discovery_date
    assert Format.card_session(c, c.discovery_date).date == c.discovery_date
  end

  test "course term fallback stays in sort but never invents a session date" do
    l =
      listing!(venue!(), %{
        kind: "class",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-10-01]
      })

    assert [result] = Catalogue.search(Query.from_params(%{}, @today)).dated
    assert result.id == l.id
    assert result.discovery_date == @today
    assert Format.card_date(result, @today) == nil
    html = render_component(&ListingComponents.listing_card/1, listing: result, today: @today)
    assert html =~ "TBA"
    assert html =~ "series-card"
    refute html =~ "data-date="
    refute html =~ "Next session"
  end

  test "known schedule retains past and future sessions, highlights next known date and preserves unknown cohorts" do
    l =
      listing!(
        venue!(),
        %{
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-10-01],
          cohorts: ["Evening"]
        },
        [~D[2026-09-01], ~D[2026-09-08], ~D[2026-09-15]]
      )

    rows = Format.session_rows(l, @today)
    assert Enum.map(rows, & &1.state) == [:past, :next, :future, :unknown]
    assert Enum.at(rows, 0).text =~ "Sep 1, 2026"
    assert Enum.at(rows, 1).text =~ "Sep 8, 2026"
    assert Enum.at(rows, 3).text == "Evening · Dates and times not confirmed"
    assert Enum.all?(Format.session_rows(l, ~D[2026-10-02]), &(&1.state != :next))
  end

  test "title-only description is hidden without changing source text; substantive text remains" do
    l = listing!(venue!(), %{title: "Climbing Club", summary: " CLIMBING club! "})
    assert Format.summary(l) == nil
    html = render_component(&ListingComponents.listing_card/1, listing: l, today: @today)
    refute html =~ "CLIMBING club!"
    assert Catalogue.get_listing(l.id).summary == " CLIMBING club! "

    assert Format.summary(%{l | summary: "Climbing Club for new climbers"}) ==
             "Climbing Club for new climbers"
  end
end
