defmodule ClimbOntario.CatalogueTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.Query

  @today ~D[2026-09-08]

  defp q(params, today \\ @today), do: Query.from_params(params, today)
  defp titles(list), do: Enum.map(list, & &1.title)

  test "windows: weekend is Sat-Sun, week is seven dates, month ends at month end" do
    assert Catalogue.window("weekend", ~D[2026-09-08]) == {~D[2026-09-12], ~D[2026-09-13]}
    assert Catalogue.window("weekend", ~D[2026-09-13]) == {~D[2026-09-13], ~D[2026-09-13]}
    assert Catalogue.window("week", ~D[2026-09-28]) == {~D[2026-09-28], ~D[2026-10-04]}
    assert Catalogue.window("month", ~D[2026-09-28]) == {~D[2026-09-28], ~D[2026-09-30]}
    assert Catalogue.window("month", ~D[2026-12-31]) == {~D[2026-12-31], ~D[2026-12-31]}
  end

  test "distance, kind and audience filters; drafts and finished things are invisible" do
    aurora = venue!()

    ottawa =
      venue!(%{slug: "altitude", name: "Altitude", city: "Ottawa", lat: 45.42, lng: -75.69})

    comp = listing!(aurora)
    _far = listing!(ottawa, %{title: "Ottawa comp"})

    social =
      listing!(aurora, %{
        title: "Women's Night",
        kind: "social",
        schedule_kind: "recurring",
        recurrence: "weekly",
        weekday: 5,
        start_date: nil,
        audience: ["women"]
      })

    _draft = listing!(aurora, %{title: "Draft", published: false})
    _done = listing!(aurora, %{title: "Done", start_date: ~D[2026-08-01]})

    _ended_series =
      listing!(aurora, %{
        title: "Ended series",
        schedule_kind: "recurring",
        recurrence: "weekly",
        weekday: 5,
        start_date: nil,
        end_date: ~D[2026-08-30]
      })

    r = Catalogue.search(q(%{"near" => "Aurora"}))
    assert titles(r.dated) == [comp.title]
    assert titles(r.ongoing) == [social.title]
    assert hd(r.dated).distance_km < 5

    assert titles(Catalogue.search(q(%{"near" => "Aurora", "kind" => "social"})).dated) == []

    assert titles(Catalogue.search(q(%{"near" => "Aurora", "for" => "women"})).ongoing) == [
             "Women's Night"
           ]

    assert Catalogue.search(q(%{})).total == 3
    assert Catalogue.get_listing(comp.id).title == comp.title
    refute Catalogue.get_listing(_draft.id)
  end

  test "date filters match confirmed occurrences only" do
    v = venue!()

    # Course runs Sep 13 - Oct 18 on Sundays; the weekend of Sep 12-13 has a class, Sep 19-20 does not.
    course =
      listing!(
        v,
        %{
          title: "Pebbles",
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-13],
          end_date: ~D[2026-10-18]
        },
        [~D[2026-09-13], ~D[2026-09-27]]
      )

    bare_course =
      listing!(v, %{
        title: "Undated course",
        kind: "class",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-11-01]
      })

    meetup =
      listing!(
        v,
        %{title: "Meetup", kind: "social", schedule_kind: "recurring", start_date: nil},
        [~D[2026-09-25]]
      )

    assert titles(Catalogue.search(q(%{"when" => "weekend"})).dated) == ["Pebbles"]
    assert titles(Catalogue.search(q(%{"when" => "weekend"}, ~D[2026-09-15])).dated) == []
    assert titles(Catalogue.search(q(%{"when" => "month"})).dated) == ["Pebbles", "Meetup"]
    assert Catalogue.search(q(%{"when" => "month"})).ongoing == []

    anytime = Catalogue.search(q(%{}))

    assert Enum.sort(titles(anytime.dated)) ==
             Enum.sort([course.title, bare_course.title, meetup.title])

    assert anytime.ongoing == []
  end

  test "offsite events use their own coordinates or drop out of radius search" do
    gym = venue!()

    _located =
      listing!(gym, %{
        title: "Downtown",
        offsite_name: "Bloor St",
        offsite_lat: 43.67,
        offsite_lng: -79.39
      })

    _unlocated = listing!(gym, %{title: "Somewhere", offsite_name: "TBA venue"})
    _at_gym = listing!(gym, %{title: "At gym"})

    assert Enum.sort(titles(Catalogue.search(q(%{"near" => "Aurora"})).dated)) == [
             "At gym",
             "Downtown"
           ]

    assert titles(Catalogue.search(q(%{"near" => "Toronto", "km" => "10"})).dated) == ["Downtown"]
    assert Catalogue.search(q(%{})).total == 3
  end

  test "province-wide results stay chronological across kinds without interleaving" do
    v = venue!()
    listing!(v, %{title: "First class", kind: "class", start_date: ~D[2026-09-09]})
    listing!(v, %{title: "Second class", kind: "class", start_date: ~D[2026-09-10]})
    listing!(v, %{title: "Later comp", start_date: ~D[2026-09-20]})
    listing!(v, %{title: "Last camp", kind: "camp", start_date: ~D[2026-10-01]})
    expected = ["First class", "Second class", "Later comp", "Last camp"]
    assert titles(Catalogue.search(q(%{})).dated) == expected
    assert titles(Catalogue.search(q(%{"near" => "Aurora"})).dated) == expected
    assert titles(Catalogue.search(q(%{"kind" => "class"})).dated) == Enum.take(expected, 2)
  end

  test "Anytime merges recurring and in-progress courses by next confirmed date" do
    v = venue!()
    listing!(v, %{title: "Later comp", start_date: ~D[2026-09-20]})

    listing!(
      v,
      %{title: "Next meetup", kind: "social", schedule_kind: "recurring", start_date: nil},
      [~D[2026-09-01], ~D[2026-09-10]]
    )

    listing!(
      v,
      %{
        title: "Course next session",
        kind: "class",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-10-01]
      },
      [~D[2026-09-01], ~D[2026-09-12]]
    )

    listing!(v, %{
      title: "Pattern only",
      kind: "social",
      schedule_kind: "recurring",
      start_date: nil,
      recurrence: "weekly",
      weekday: 3
    })

    listing!(
      v,
      %{title: "Past sessions only", kind: "social", schedule_kind: "recurring", start_date: nil},
      [~D[2026-09-01]]
    )

    listing!(v, %{
      title: "Unannounced",
      kind: "camp",
      schedule_kind: "unscheduled",
      start_date: nil
    })

    result = Catalogue.search(q(%{"unscheduled" => "1"}))
    assert titles(result.dated) == ["Next meetup", "Course next session", "Later comp"]

    assert Enum.sort(titles(result.ongoing)) == [
             "Past sessions only",
             "Pattern only"
           ]

    assert result.total == 5
    assert titles(Catalogue.search(q(%{"kind" => "social"})).dated) == ["Next meetup"]

    assert titles(Catalogue.search(q(%{"when" => "week"})).dated) == [
             "Next meetup",
             "Course next session"
           ]
  end

  test "OCF has a separate discovery filter and code-owned badge" do
    v = venue!()
    ocf = listing!(v, %{ocf: true, title: "Sanctioned", label: "Anything"})
    other = listing!(v, %{ocf: false, title: "Local comp", label: "OCF sanctioned"})
    assert titles(Catalogue.search(q(%{"kind" => "ocf"})).dated) == [ocf.title]
    assert titles(Catalogue.search(q(%{"kind" => "competition"})).dated) == [other.title]
    assert ClimbOntarioWeb.Format.badge(ocf) == "OCF competition"
    assert ClimbOntarioWeb.Format.badge(other) == "Competition"

    assert ClimbOntario.Catalogue.Listing.discovery_kinds() ==
             ~w(ocf competition social class camp)
  end

  test "two same-day cohorts use actual venues and unknown venues never borrow organizer coordinates" do
    v = venue!()
    away = venue!(%{slug: "away", name: "Ottawa venue", city: "Ottawa", lat: 45.42, lng: -75.69})

    l =
      listing!(v, %{cohorts: ["Morning", "Evening", "Unannounced"], bundled_by: "day", location_kind: "multiple"}, [
        %{
          date: ~D[2026-12-12],
          cohort: "Morning",
          start_time: ~T[09:00:00],
          end_time: ~T[11:00:00],
          timezone: "America/Toronto",
          location_kind: "venue",
          venue_id: v.id
        },
        %{
          date: ~D[2026-12-12],
          cohort: "Evening",
          start_time: ~T[18:00:00],
          timezone: "America/Toronto",
          location_kind: "venue",
          venue_id: away.id
        }
      ])

    assert length(l.occurrences) == 2
    assert Catalogue.search(q(%{"near" => "Ottawa", "km" => "10"})).total == 1
    assert Catalogue.search(q(%{"near" => "Aurora", "km" => "10"})).total == 1
    assert ClimbOntarioWeb.Format.location_line(l) =~ "Multiple venues"
    lines = ClimbOntarioWeb.Format.session_lines(l)
    assert Enum.any?(lines, &(&1 =~ "Morning" and &1 =~ "9–11 am" and &1 =~ "Aurora"))
    assert Enum.any?(lines, &(&1 =~ "Evening" and &1 =~ "6 pm" and &1 =~ "Ottawa"))
    assert "Unannounced · Dates and times not confirmed" in lines
    unknown = listing!(v, %{location_kind: "unknown", title: "Unknown venue"})

    offsite =
      listing!(v, %{
        location_kind: "offsite",
        offsite_name: "Park",
        offsite_city: "Toronto",
        offsite_address: "10 Park Rd",
        title: "Offsite"
      })

    assert ClimbOntarioWeb.Format.location_line(unknown) =~ "Venue not announced"
    assert ClimbOntarioWeb.Format.location_line(offsite) == "Park · Toronto"
    assert Catalogue.search(q(%{"near" => "Aurora", "km" => "10"})).total == 1
    assert Catalogue.search(q(%{})).total == 3
  end

  test "patterns invent no dates; unannounced listings require reveal and never match date filters" do
    v = venue!()

    listing!(v, %{
      kind: "social",
      schedule_kind: "recurring",
      start_date: nil,
      recurrence: "weekly",
      weekday: 5
    })

    listing!(v, %{kind: "camp", schedule_kind: "unscheduled", start_date: nil})
    assert Catalogue.search(q(%{})).total == 1
    assert Catalogue.search(q(%{"unscheduled" => "1"})).total == 1
    assert Catalogue.search(q(%{"when" => "month", "unscheduled" => "1"})).total == 0
  end

  test "query round-trips through URL params and shrugs off malformed input" do
    query =
      q(%{
        "near" => "L4G 1A1",
        "kind" => "competition,social",
        "when" => "weekend",
        "for" => "youth",
        "km" => "100"
      })

    assert query.near.label == "L4G, Canada"

    assert Query.to_params(query) == [
             near: "L4G 1A1",
             kind: "competition,social",
             from: "2026-09-12",
             to: "2026-09-13",
             for: "youth",
             km: 100
           ]

    assert Query.to_params(q(%{"when" => "bogus", "km" => "-3"})) == []

    assert Query.to_params(
             q(%{"near" => %{"x" => "Aurora"}, "kind" => ["a"], "km" => %{}, "when" => [1]})
           ) == []
  end
end
