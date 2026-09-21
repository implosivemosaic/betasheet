defmodule ClimbOntario.Catalogue.SeriesTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.{Import, Query, Series}
  alias ClimbOntarioWeb.Format

  test "arbitrary course ID: selected complete cohort position includes past/filter-excluded sessions only in that cohort" do
    l =
      listing!(
        venue!(),
        %{
          id: 87654,
          title: "Two groups",
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2027-01-01],
          end_date: ~D[2027-02-28],
          cohorts: ["Kids", "Teens"],
          bundled_by: "age",
          classes: [%{name: "Kids", ages: "6–12"}, %{name: "Teens", ages: "13–17"}],
          complete_cohorts: ["Teens"]
        },
        [
          %{date: ~D[2027-01-02], cohort: "Teens"},
          %{date: ~D[2027-01-03], cohort: "Kids"},
          %{date: ~D[2027-01-09], cohort: "Teens"},
          %{date: ~D[2027-01-16], cohort: "Teens"},
          %{date: ~D[2027-01-23], cohort: "Kids"}
        ]
      )

    for {from, index} <- [{"2027-01-01", 1}, {"2027-01-09", 2}, {"2027-01-16", 3}] do
      q =
        Query.from_params(%{"from" => from, "to" => "2027-01-22", "days" => "6"}, ~D[2027-01-01])

      assert [result] = Catalogue.search(q).dated
      selected = Format.card_session(result, result.discovery_date)
      assert selected.id == result.discovery_occurrence_id
      assert selected.date == result.discovery_date
      assert selected.cohort == "Teens"
      assert Series.position(result, selected) == %{index: index, total: 3}
    end

    teen = Enum.find(l.occurrences, &(&1.cohort == "Teens"))
    kid = Enum.find(l.occurrences, &(&1.cohort == "Kids"))
    assert Series.position(l, kid) == %{index: 1, total: 2}
    assert Series.position(l, %{teen | id: -1}) == nil
    assert Series.position(l, %{teen | listing_id: -1}) == nil
    assert Series.position(l, nil) == nil
    assert Series.position(%{l | complete_cohorts: []}, teen) == %{index: 1, total: 3}
    assert Series.position(%{l | schedule_kind: "recurring"}, teen) == nil
  end

  test "unnamed completeness is explicit and importer enforces groups, finite courses, uniqueness and nonempty sessions atomically" do
    l =
      listing!(
        venue!(),
        %{
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2027-01-01],
          end_date: ~D[2027-01-31],
          cohorts: ["Kids"]
        },
        [~D[2027-01-02], ~D[2027-01-09]]
      )

    assert l.complete_cohorts == []
    {:ok, complete} = Import.put_listing(%{id: l.id, complete_cohorts: ["__unnamed__"]})
    selected = Enum.find(complete.occurrences, &(&1.date == ~D[2027-01-09]))
    assert Series.position(complete, selected) == %{index: 2, total: 2}
    assert Enum.map(complete.occurrences, & &1.id) == Enum.map(l.occurrences, & &1.id)

    for attrs <- [
          %{complete_cohorts: ["Missing"]},
          %{complete_cohorts: ["Kids"]},
          %{complete_cohorts: ["__unnamed__", "__unnamed__"]},
          %{complete_cohorts: nil},
          %{cohorts: ["__unnamed__"]},
          %{schedule_kind: "recurring"}
        ] do
      assert {:error, _} = Import.put_listing(Map.put(attrs, :id, l.id))
    end

    assert {:error, cs} = Import.put_listing(%{id: l.id}, [])
    assert cs.errors[:complete_cohorts]
    assert length(Catalogue.get_listing(l.id).occurrences) == 2
    assert {:ok, cleared} = Import.put_listing(%{id: l.id, complete_cohorts: []}, [])
    assert cleared.occurrences == []
  end
end
