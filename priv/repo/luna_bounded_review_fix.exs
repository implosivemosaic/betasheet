alias ClimbOntario.{Repo, Catalogue.Import}
alias ClimbOntario.Catalogue.Listing
alias ClimbOntario.Catalogue.Occurrence
import Ecto.Query
fix = fn id, changes, sessions ->
  l = Repo.get!(Listing, id) |> Map.from_struct()
  attrs = Map.merge(l, changes) |> Map.drop([:__meta__, :occurrences, :inserted_at, :updated_at]) |> Map.put(:published, false)
  case Import.put_listing(attrs, sessions) do
    {:ok, x} -> IO.puts("fixed #{id}: #{length(x.occurrences)} occurrences")
    {:error, e} -> IO.inspect(e); raise "failed #{id}"
  end
end
fix.(11, %{confidence: "tentative", summary: "Gym-announced Canadian national boulder and lead championship window, February 12–16, 2027; exact daily schedule is unconfirmed.", caveat: "The February 12–16 window is tentative and was not confirmed by the OCF follow-up."}, [%{date: ~D[2027-02-12], cohort: "tentative window"}, %{date: ~D[2027-02-16], cohort: "tentative window"}])
fix.(9, %{summary: "OCF speed qualifying competition."}, [%{date: ~D[2026-11-22]}])
fix.(10, %{summary: "OCF speed provincial championship."}, [%{date: ~D[2027-01-10]}])
fix.(30, %{summary: "Youth climbing lessons for ages 5–6."}, Repo.all(Ecto.Query.from(o in ClimbOntario.Catalogue.Occurrence, where: o.listing_id == 30)) |> Enum.map(&Map.from_struct/1) |> Enum.map(&Map.take(&1, [:date, :cohort, :start_time, :end_time])))
fix.(99, %{schedule_kind: "unscheduled", confidence: "tentative", start_date: nil, end_date: nil, start_time: nil, end_time: nil, summary: "September 9 start announced; year and remaining dates need confirmation.", caveat: "The saved source has a September 9 start but no confirmed year, end date, or remaining dates; the linked July booking heading is stale."}, [])
IO.puts("bounded review fixes complete")
