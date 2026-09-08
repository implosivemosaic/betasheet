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
        start_date: nil,
        audience: ["women"]
      })

    _draft = listing!(aurora, %{title: "Draft", published: false})
    _done = listing!(aurora, %{title: "Done", start_date: ~D[2026-08-01]})

    _ended_series =
      listing!(aurora, %{
        title: "Ended series",
        schedule_kind: "recurring",
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
    assert Enum.sort(titles(anytime.dated)) == Enum.sort([course.title, bare_course.title])
    assert titles(anytime.ongoing) == [meetup.title]
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

  test "query round-trips through URL params and shrugs off malformed input" do
    query =
      q(%{
        "near" => "L4G 1A1",
        "kind" => "competition,social",
        "when" => "weekend",
        "for" => "youth",
        "km" => "100"
      })

    assert query.near.label == "Aurora"

    assert Query.to_params(query) == [
             near: "L4G 1A1",
             kind: "competition,social",
             when: "weekend",
             for: "youth",
             km: 100
           ]

    assert Query.to_params(q(%{"when" => "bogus", "km" => "-3"})) == []

    assert Query.to_params(
             q(%{"near" => %{"x" => "Aurora"}, "kind" => ["a"], "km" => %{}, "when" => [1]})
           ) == []
  end
end
