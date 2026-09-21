alias ClimbOntario.{Repo, Catalogue.Import}
alias ClimbOntario.Catalogue.Listing
put = fn id, changes, sessions ->
  l = Repo.get!(Listing, id) |> Map.from_struct()
  attrs = Map.merge(l, changes) |> Map.drop([:__meta__, :occurrences, :inserted_at, :updated_at]) |> Map.put(:published, false)
  case Import.put_listing(attrs, sessions) do
    {:ok, x} -> IO.puts("repaired #{id}: #{length(x.occurrences)} occurrences")
    {:error, e} -> IO.inspect(e); raise "repair failed #{id}"
  end
end
tz="America/Toronto"
s8=Enum.map(~w(2026-09-09 2026-09-11 2026-09-16 2026-09-18 2026-09-23 2026-09-25 2026-09-30),&%{date: &1,start_time: ~T[19:00:00],end_time: ~T[20:00:00]})
put.(8,%{schedule_kind: "recurring",recurrence: "weekly",weekday: 3,start_date: nil,end_date: nil,start_time: nil,end_time: nil,summary: "Yoga sessions on Wednesdays and Fridays at the Parc.",caveat: "Seven September 2026 dates are confirmed; later recurrence endpoint is not specified.",timezone: tz},s8)
blaze=fn name,st,et,ds->Enum.map(ds,&%{date: &1,cohort: name,start_time: st,end_time: et})end
dm = ~w(2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26)
dt = ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20)
ds = ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-10 2026-10-17 2026-10-24)
put.(30,%{schedule_kind: "course",start_date: ~D[2026-09-14],end_date: ~D[2026-10-26],cohorts: ["Monday","Tuesday","Saturday"],summary: "Six-class youth climbing cohorts for ages 5–6: Mondays and Tuesdays 17:45–18:45, or Saturdays 10:15–11:15."},blaze.("Monday",~T[17:45:00],~T[18:45:00],dm)++blaze.("Tuesday",~T[17:45:00],~T[18:45:00],dt)++blaze.("Saturday",~T[10:15:00],~T[11:15:00],ds))
independent=fn id,title,summary,dates->put.(id,%{schedule_kind: "recurring",start_date: nil,end_date: nil,start_time: nil,end_time: nil,weekday: 3,recurrence: "weekly",title: title,summary: summary},dates) end
independent.(225,"SPARK: Intro to Bouldering — ongoing classes","Independent two-hour introductory bouldering lessons on the confirmed September dates.",Enum.map(~w(2026-09-09 2026-09-16 2026-09-23 2026-09-30),&%{date: &1,start_time: ~T[19:00:00],end_time: ~T[21:00:00]})++Enum.map(~w(2026-09-12 2026-09-19 2026-09-26),&%{date: &1,start_time: ~T[13:00:00],end_time: ~T[15:00:00]}))
independent.(226,"FUEL: The Next Step in Bouldering — September 2026 classes","Independent two-hour next-step bouldering lessons on the confirmed September dates.",[%{date: ~D[2026-09-12],start_time: ~T[15:00:00],end_time: ~T[17:00:00]},%{date: ~D[2026-09-23],start_time: ~T[17:00:00],end_time: ~T[19:00:00]},%{date: ~D[2026-09-26],start_time: ~T[15:00:00],end_time: ~T[17:00:00]}])
put.(97,%{summary: "Introductory bouldering sessions; exact recurring schedule is not established.",caveat: "Website and booking descriptions conflict on days/times; no single schedule is asserted."},[])
put.(98,%{summary: "Beginner bouldering sessions; published days and times conflict.",caveat: "Website, booking body, and live calendar disagree on the schedule; confirm the current time with RockHaus."},[])
put.(99,%{summary: "Eight Wednesday one-hour Mini Boulder Crushers sessions beginning September 9, 2026; later dates are not individually listed."},[])
put.(100,%{summary: "Weekly Tuesday student climbing offer; exact hours and season bounds are not stated."},[])
put.(204,%{summary: "Monthly No Boys Allowed climbing social for women and non-binary climbers; time is not stated."},[])
put.(9,%{summary: "Official OCF speed provincials qualifier on November 22, 2026; athlete schedule and registration details are unpublished."},[%{date: ~D[2026-11-22]}])
put.(10,%{summary: "Official OCF Speed Provincials on January 10, 2027; athlete schedule and registration details are unpublished."},[%{date: ~D[2027-01-10]}])
put.(11,%{summary: "Gym-announced Canadian national boulder and lead championship window, February 12–16, 2027; exact daily schedule is unconfirmed.",cohorts: ["tentative window"],caveat: "The February 12–16 window is tentative in the saved gym handoff and was not confirmed by the OCF follow-up."},[%{date: ~D[2027-02-12],cohort: "tentative window"},%{date: ~D[2027-02-16],cohort: "tentative window"}])
IO.puts("review repairs complete")
