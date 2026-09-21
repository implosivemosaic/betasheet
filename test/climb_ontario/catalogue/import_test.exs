defmodule ClimbOntario.Catalogue.ImportTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue.{Import, Listing, Occurrence}
  alias ClimbOntario.Repo

  setup do
    %{venue: venue!()}
  end

  test "the three reviewed examples load idempotently without research access" do
    for id <- [30, 10, 38], do: venue!(%{source_gym_id: id, slug: "example-#{id}"})
    Code.eval_file("priv/repo/examples.exs")
    assert Repo.aggregate(Listing, :count) == 3
    assert Enum.sort(Enum.map(Repo.all(Listing), & &1.id)) == [17, 28, 209]
    assert Enum.all?(Repo.all(Listing), & &1.published)
    assert Repo.aggregate(Occurrence, :count) == 11
    Repo.update_all(Listing, set: [catalogue_updated_on: ~D[2026-01-01]])
    Code.eval_file("priv/repo/examples.exs")
    assert Enum.all?(Repo.all(Listing), &(&1.catalogue_updated_on == ~D[2026-01-01]))

    for id <- [17, 28, 209] do
      l = ClimbOntario.Catalogue.get_listing(id)

      lines =
        ClimbOntarioWeb.ListingHTML.when_lines(l, ~D[2026-09-08])
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")

      assert Enum.all?(l.occurrences, &(&1.timezone == "America/Toronto"))
      assert lines =~ "America/Toronto"
      refute Enum.join(ClimbOntarioWeb.Format.session_lines(l)) =~ "America/Toronto"
      refute lines =~ "Timezone not confirmed"
    end
  end

  test "a skeleton inserts unpublished; publishing needs every judgment field", %{venue: v} do
    {:ok, l} =
      Import.put_listing(%{id: 5, venue_id: v.id, title: "Thing", checked_on: ~D[2026-09-06]})

    refute l.published
    assert {:error, cs} = Import.publish(5)

    assert Enum.sort(Keyword.keys(cs.errors)) ==
             ~w(confidence kind link link_kind schedule_kind sources summary)a
  end

  test "published rows require HTTP(S) evidence; empty sources remain valid for drafts", %{
    venue: v
  } do
    draft = listing!(v, %{published: false, sources: []})
    assert {:error, cs} = Import.publish(draft.id)
    assert cs.errors[:sources]
    refute Repo.get!(Listing, draft.id).published

    assert {:error, cs} =
             Import.put_listing(%{
               id: draft.id,
               published: true,
               sources: ["javascript:alert(1)"]
             })

    assert cs.errors[:sources]

    {:ok, published} =
      Import.put_listing(%{
        id: draft.id,
        published: true,
        sources: ["https://evidence.example/event"]
      })

    assert published.published

    assert {:error, cs} =
             Import.put_listing(%{id: draft.id, sources: [], title: "Must roll back"})

    assert cs.errors[:sources]
    assert Repo.get!(Listing, draft.id).sources == published.sources
    assert Repo.get!(Listing, draft.id).title == published.title
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

  test "omitted sessions preserve snapshots; explicit empty replaces; evidence and no-op rebuilds do not refresh catalogue date",
       %{venue: v} do
    l = listing!(v, %{start_time: ~T[09:00:00], timezone: "America/Toronto"}, [~D[2026-12-12]])
    Repo.update_all(Listing, set: [catalogue_updated_on: ~D[2026-01-01]])

    {:ok, checked} =
      Import.put_listing(%{
        id: l.id,
        checked_on: ~D[2026-09-09],
        sources: ["https://source.example/evidence"]
      })

    assert checked.catalogue_updated_on == ~D[2026-01-01]
    assert Enum.map(checked.occurrences, & &1.id) == Enum.map(l.occurrences, & &1.id)
    {:ok, same} = Import.put_listing(%{id: l.id}, [~D[2026-12-12]])
    assert same.catalogue_updated_on == ~D[2026-01-01]
    {:ok, changed} = Import.put_listing(%{id: l.id, start_time: ~T[10:00:00]})
    assert hd(changed.occurrences).start_time == ~T[09:00:00]
    assert changed.catalogue_updated_on == ClimbOntario.Clock.today()
    {:ok, empty} = Import.put_listing(%{id: l.id}, [])
    assert empty.occurrences == []
  end

  test "malformed URLs, chronology and sessions return changesets and roll back", %{venue: v} do
    l = listing!(v, %{}, [~D[2026-12-12]])

    for url <- ["javascript:alert(1)", "/relative", "https://", "https://bad host/e"] do
      assert {:error, cs} = Import.put_listing(%{id: l.id, link: url})
      assert cs.errors[:link]
    end

    assert {:error, _} = Import.put_listing(%{id: l.id, cohorts: nil})
    assert {:error, _} = Import.put_listing(%{id: l.id, cohorts: [nil]})
    assert {:error, _} = Import.put_listing(%{id: l.id, end_date: ~D[2026-12-11]})

    assert {:error, _} =
             Import.put_listing(%{id: l.id, start_time: "12:00:00", end_time: "09:00:00"})

    for sessions <- [
          ["not-a-date"],
          [%{date: "2026-12-13"}],
          [%{date: "2026-12-12", start_time: "nope"}],
          [%{date: "2026-12-12", timezone: "Mars/Olympus"}],
          [%{date: "2026-12-12", cohort: "Missing"}],
          [42],
          "2026-12-12",
          [~D[2026-12-12], ~D[2026-12-12]],
          [%{date: "2026-12-12", location_kind: "venue", venue_id: 999_999}]
        ] do
      assert {:error, %Ecto.Changeset{}} =
               Import.put_listing(%{id: l.id, title: "Must roll back"}, sessions)

      assert Repo.get!(Listing, l.id).title == l.title
      assert Enum.map(Repo.all(Occurrence), & &1.id) == Enum.map(l.occurrences, & &1.id)
    end
  end

  test "recurring needs structured evidence; unannounced schedules stay honest", %{venue: v} do
    l =
      listing!(v, %{
        published: false,
        schedule_kind: "recurring",
        start_date: nil,
        schedule_note: "Every imaginary Tuesday"
      })

    assert {:error, cs} = Import.publish(l.id)
    assert cs.errors[:recurrence]

    {:ok, recurring} =
      Import.put_listing(%{
        id: l.id,
        recurrence: "monthly",
        weekday: 5,
        month_week: -1,
        published: true
      })

    assert recurring.occurrences == []
    assert ClimbOntarioWeb.Format.pattern(recurring) =~ "Last Fri of the month"
    assert ClimbOntarioWeb.Format.when_line(recurring) == "Dates not confirmed"

    assert {:error, _} =
             Import.put_listing(%{id: l.id, recurrence: nil, weekday: nil, month_week: nil}, [])

    assert {:error, _} = Import.put_listing(%{id: l.id, recurrence: "monthly", month_week: nil})

    assert {:error, _} =
             Import.put_listing(
               %{
                 id: l.id,
                 schedule_kind: "unscheduled",
                 recurrence: nil,
                 weekday: nil,
                 month_week: nil
               },
               [~D[2026-12-12]]
             )
  end
end
