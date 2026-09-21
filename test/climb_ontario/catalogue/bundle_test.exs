defmodule ClimbOntario.Catalogue.BundleTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.Import

  defp attrs(extra) do
    Map.merge(
      %{
        id: System.unique_integer([:positive]),
        venue_id: venue!(%{slug: "v#{System.unique_integer([:positive])}"}).id,
        title: "Youth lessons",
        kind: "class",
        label: "class",
        summary: "Lessons.",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-10-31],
        confidence: "confirmed",
        link: "https://gym.example/lessons",
        link_kind: "event",
        sources: ["https://gym.example/lessons"],
        checked_on: ~D[2026-09-21],
        published: true
      },
      extra
    )
  end

  test "a new bundle must say what its classes are split by; each class carries that fact" do
    assert {:error, cs} = Import.put_listing(attrs(%{cohorts: ["Ages 6–8", "Ages 9–12"]}), [])
    assert cs.errors[:bundled_by]

    assert {:error, cs} = Import.put_listing(attrs(%{cohorts: ["A", "B"], bundled_by: "size"}), [])
    assert cs.errors[:bundled_by]

    assert {:error, cs} = Import.put_listing(attrs(%{cohorts: ["A", "B"], bundled_by: "age"}), [])
    assert {"must describe every class in cohorts", _} = cs.errors[:classes]

    assert {:error, cs} =
             Import.put_listing(
               attrs(%{cohorts: ["A", "B"], bundled_by: "age", classes: [%{name: "A", ages: "6–8"}, %{name: "B"}]}),
               []
             )

    assert {"each class needs ages", _} = cs.errors[:classes]

    assert {:error, cs} =
             Import.put_listing(
               attrs(%{cohorts: ["A", "B"], bundled_by: "age", classes: [%{name: "A", ages: "6–8"}, %{name: "C", ages: "9+"}]}),
               []
             )

    assert {"must name distinct classes from cohorts", _} = cs.errors[:classes]

    {:ok, l} =
      Import.put_listing(
        attrs(%{
          cohorts: ["Ages 6–8", "Ages 9–12"],
          bundled_by: "age",
          classes: [%{"name" => "Ages 6–8", "ages" => "6–8"}, %{"name" => "Ages 9–12", "ages" => "9–12"}]
        })
        |> Map.new(fn {k, v} -> {to_string(k), v} end),
        [%{date: ~D[2026-09-07], cohort: "Ages 6–8"}, %{date: ~D[2026-09-08], cohort: "Ages 9–12"}]
      )

    assert l.bundled_by == "age"
    assert Enum.map(l.classes, &{&1.name, &1.ages}) == [{"Ages 6–8", "6–8"}, {"Ages 9–12", "9–12"}]

    # An identical reimport is not a substantive change; partial updates preserve the classes.
    Repo.update_all(from(x in Catalogue.Listing, where: x.id == ^l.id), set: [catalogue_updated_on: ~D[2026-01-01]])
    {:ok, again} = Import.put_listing(%{id: l.id, bundled_by: "age", classes: [%{name: "Ages 6–8", ages: "6–8"}, %{name: "Ages 9–12", ages: "9–12"}]})
    assert again.catalogue_updated_on == ~D[2026-01-01]
    {:ok, same} = Import.put_listing(%{id: l.id, summary: "Updated."})
    assert Enum.map(same.classes, & &1.name) == ["Ages 6–8", "Ages 9–12"]
    assert Catalogue.get_listing(l.id).bundled_by == "age"
    assert {:error, cs} = Import.put_listing(attrs(%{cohorts: ["Only"], bundled_by: "day"}), [])
    assert cs.errors[:bundled_by]
  end

  test "day bundles need no class facts; mixed needs at least one per class" do
    assert {:ok, l} = Import.put_listing(attrs(%{cohorts: ["Monday", "Thursday"], bundled_by: "day"}), [])
    assert l.classes == []

    assert {:error, cs} =
             Import.put_listing(
               attrs(%{cohorts: ["U13", "Open"], bundled_by: "mixed", classes: [%{name: "U13", ages: "under 13"}, %{name: "Open"}]}),
               []
             )

    assert {"each class needs ages, a level or a format", _} = cs.errors[:classes]

    assert {:ok, _} =
             Import.put_listing(
               attrs(%{cohorts: ["U13", "Open"], bundled_by: "mixed", classes: [%{name: "U13", ages: "under 13"}, %{name: "Open", level: "Open"}]}),
               []
             )
  end

  test "bundles written before the rule pass until their cohorts change" do
    l = listing!(venue!(%{slug: "legacy"}), %{cohorts: ["Morning", "Evening"], bundled_by: "day"}, [])
    # Simulate a legacy row: clear the classification directly.
    Repo.update_all(from(x in Catalogue.Listing, where: x.id == ^l.id), set: [bundled_by: nil])
    assert {:ok, _} = Import.put_listing(%{id: l.id, summary: "Still fine."})
    assert {:error, cs} = Import.put_listing(%{id: l.id, cohorts: ["Morning", "Evening", "Night"]})
    assert cs.errors[:bundled_by]
  end
end
