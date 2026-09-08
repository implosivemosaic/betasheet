defmodule ClimbOntario.Catalogue.ImportTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue.{Import, Listing, Occurrence}
  alias ClimbOntario.Repo

  setup do
    %{venue: venue!()}
  end

  test "a skeleton inserts unpublished; publishing needs every judgment field", %{venue: v} do
    {:ok, l} =
      Import.put_listing(%{id: 5, venue_id: v.id, title: "Thing", checked_on: ~D[2026-09-06]})

    refute l.published
    assert {:error, cs} = Import.publish(5)

    assert Enum.sort(Keyword.keys(cs.errors)) ==
             ~w(confidence kind label link link_kind schedule_kind summary)a
  end

  test "closed vocabularies and schedule shapes are enforced", %{venue: v} do
    assert {:error, cs} =
             Import.put_listing(%{
               id: 6,
               venue_id: v.id,
               title: "T",
               checked_on: ~D[2026-09-06],
               kind: "party",
               confidence: "maybe",
               link_kind: "web"
             })

    assert Enum.sort(Keyword.keys(cs.errors)) == [:confidence, :kind, :link_kind]

    assert {:error, cs} =
             Import.put_listing(%{
               id: 7,
               venue_id: v.id,
               title: "T",
               checked_on: ~D[2026-09-06],
               schedule_kind: "course",
               start_date: ~D[2026-10-01],
               end_date: ~D[2026-09-01]
             })

    assert cs.errors[:end_date]
  end

  test "listing and dates are written together or not at all", %{venue: v} do
    l =
      listing!(
        v,
        %{
          title: "Course",
          kind: "class",
          schedule_kind: "course",
          start_date: ~D[2026-09-13],
          end_date: ~D[2026-10-18]
        },
        [~D[2026-09-13], ~D[2026-09-20]]
      )

    assert Repo.aggregate(Occurrence, :count) == 2

    assert {:error, _} =
             Import.put_listing(
               %{
                 id: l.id,
                 venue_id: v.id,
                 title: "Course",
                 checked_on: ~D[2026-09-06],
                 kind: "nope"
               },
               [~D[2026-12-01]]
             )

    assert Enum.map(Repo.all(Occurrence), & &1.date) == [~D[2026-09-13], ~D[2026-09-20]]
    assert Repo.get!(Listing, l.id).kind == "class"

    {:ok, _} =
      Import.put_listing(
        %{id: l.id, venue_id: v.id, title: "Course", checked_on: ~D[2026-09-06], kind: "class"},
        [~D[2026-09-27]]
      )

    assert Enum.map(Repo.all(Occurrence), & &1.date) == [~D[2026-09-27]]
  end
end
