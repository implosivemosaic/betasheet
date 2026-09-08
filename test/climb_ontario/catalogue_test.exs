defmodule ClimbOntario.CatalogueTest do
  use ClimbOntario.DataCase, async: true
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.Query

  @today ~D[2026-09-08]

  test "weekend window is the coming Saturday and Sunday" do
    assert Catalogue.window("weekend", ~D[2026-09-08]) == {~D[2026-09-12], ~D[2026-09-13]}
    assert Catalogue.window("weekend", ~D[2026-09-13]) == {~D[2026-09-13], ~D[2026-09-13]}
    assert Catalogue.window("weekend", ~D[2026-09-12]) == {~D[2026-09-12], ~D[2026-09-13]}
  end

  test "search filters by distance, kind, audience and window; recurring goes to ongoing" do
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

    course =
      listing!(aurora, %{
        title: "Kids course",
        kind: "class",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-11-01]
      })

    _unlisted = listing!(aurora, %{title: "Past", listed: false, start_date: ~D[2026-08-01]})

    _unscheduled =
      listing!(aurora, %{title: "TBA", schedule_kind: "unscheduled", start_date: nil})

    near = Query.from_params(%{"near" => "Aurora"}, @today)
    r = Catalogue.search(near)
    assert Enum.map(r.dated, & &1.title) == ["Kids course", comp.title]
    assert Enum.map(r.ongoing, & &1.title) == [social.title]
    assert hd(r.dated).distance_km < 5

    r = Catalogue.search(%{near | kinds: ["competition"]})
    assert Enum.map(r.dated, & &1.id) == [comp.id]

    r = Catalogue.search(%{near | when: "week"})
    assert Enum.map(r.dated, & &1.id) == [course.id]

    r = Catalogue.search(%{near | audience: ["women"]})
    assert r.dated == [] and Enum.map(r.ongoing, & &1.id) == [social.id]

    r = Catalogue.search(%{near | unscheduled: true})
    assert "TBA" in Enum.map(r.ongoing, & &1.title)

    everywhere = Query.from_params(%{}, @today)
    assert Catalogue.search(everywhere).total == 4
  end

  test "query round-trips through URL params, dropping defaults" do
    q =
      Query.from_params(
        %{
          "near" => "L4G 1A1",
          "kind" => "competition,social",
          "when" => "weekend",
          "for" => "youth",
          "km" => "100"
        },
        @today
      )

    assert q.near.label == "Aurora"

    assert Query.to_params(q) == [
             near: "L4G 1A1",
             kind: "competition,social",
             when: "weekend",
             for: "youth",
             km: 100
           ]

    assert Query.to_params(Query.from_params(%{"when" => "bogus", "km" => "-3"}, @today)) == []
  end
end
