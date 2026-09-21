defmodule ClimbOntario.Catalogue.DateFiltersTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.Query
  defp search(p), do: Catalogue.search(Query.from_params(p, ~D[2026-09-01]))

  test "full-series sessions match November but not holiday gaps; weekdays OR and range AND" do
    l =
      listing!(
        venue!(),
        %{
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-12-31]
        },
        [~D[2026-09-07], ~D[2026-11-02], ~D[2026-11-07]]
      )

    p = %{"from" => "2026-11-01", "to" => "2026-11-30", "days" => "1,6"}
    assert [%{id: id, discovery_date: ~D[2026-11-02]}] = search(p).dated
    assert id == l.id

    assert search(%{p | "days" => "6"}).dated |> hd() |> Map.fetch!(:discovery_date) ==
             ~D[2026-11-07]

    assert search(%{p | "from" => "2026-11-08"}).total == 0
    assert search(%{p | "days" => "2"}).total == 0
  end

  test "date and radius must belong to same occurrence and sort by matching location date" do
    v = venue!()
    away = venue!(%{slug: "away", lat: 45.42, lng: -75.69})

    listing!(v, %{kind: "social", schedule_kind: "recurring", start_date: nil}, [
      %{date: "2026-11-02", location_kind: "venue", venue_id: away.id},
      %{date: "2026-11-07", location_kind: "venue", venue_id: v.id}
    ])

    p = %{"near" => "Aurora", "km" => "10", "from" => "2026-11-01", "to" => "2026-11-30"}
    assert search(p).dated |> hd() |> Map.fetch!(:discovery_date) == ~D[2026-11-07]
    assert search(Map.put(p, "days", "1")).total == 0
    assert search(Map.put(p, "days", "6")).total == 1
  end

  test "known intervals intersect weekdays without speculative recurring dates; historical range is upcoming-only" do
    v = venue!()

    listing!(v, %{
      schedule_kind: "multi_day",
      start_date: ~D[2026-11-01],
      end_date: ~D[2026-11-05]
    })

    listing!(v, %{title: "Saturday", start_date: ~D[2026-11-07]})
    listing!(v, %{schedule_kind: "recurring", start_date: nil, recurrence: "weekly", weekday: 6})

    assert search(%{"from" => "2026-11-01", "to" => "2026-11-05", "days" => "1,6"}).dated
           |> hd()
           |> Map.fetch!(:discovery_date) == ~D[2026-11-02]

    assert search(%{"days" => "6"}).total == 1
    assert search(%{"to" => "2026-08-31"}).total == 0

    for params <- [
          %{"from" => "bad"},
          %{"from" => %{}},
          %{"from" => "2026-12-01", "to" => "2026-11-01"}
        ] do
      q = Query.from_params(Map.put(params, "days", "1,6,nope"), ~D[2026-09-01])
      assert q.from == nil and q.to == nil and q.days == [1, 6]
    end

    assert ClimbOntarioWeb.Format.audience_label("queer") == "LGBTQ+"
  end
end
