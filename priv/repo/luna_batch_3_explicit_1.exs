alias ClimbOntario.Catalogue.Import

# Boundary guard: this batch is limited to manifest IDs, never another worker's assignments.
manifest = Jason.decode!(File.read!("/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"))
allowed = (manifest["3"]["first_ten"] ++ manifest["3"]["remaining_ids"]) |> Enum.map(fn x -> if is_map(x), do: x["id"], else: x end) |> MapSet.new()
targets = [7, 215, 216, 217, 218, 219, 221, 222, 223, 224]
unless Enum.all?(targets, &MapSet.member?(allowed, &1)), do: raise "target outside worker 3 manifest"

put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences")
    {:error, cs} -> IO.inspect(cs, label: "REPAIR FAILED #{attrs[:id]}"); raise "repair failed"
  end
end
tz = "America/Toronto"

defmodule ExplicitBatch3Dates do
  def sessions(cohorts) do
    Enum.flat_map(cohorts, fn {name, start_time, end_time, dates} ->
      Enum.map(dates, &%{date: &1, cohort: name, start_time: start_time, end_time: end_time})
    end)
  end
end

put!.(%{id: 7, venue_id: 22, title: "We Are 6 Anniversary — Boulder Scramble Competition", kind: "competition", ocf: false, cohorts: [], timezone: tz, location_kind: "venue", summary: "80s-themed anniversary boulder scramble with peer judging for climbers aged 12+.", schedule_kind: "one_off", start_date: ~D[2026-10-03], end_date: ~D[2026-10-03], start_time: ~T[16:00:00], end_time: ~T[19:00:00], audience: ["youth"], ages: "Ages 12+", link: "https://www.aspireclimbing.com/whitby/anniversary-event", link_kind: "registration", confidence: "confirmed", caveat: nil, sources: ["https://www.aspireclimbing.com/whitby/anniversary-event", "https://www.instagram.com/aspirewhitby/p/DcmFwpzkUNR/"], checked_on: ~D[2026-09-06], published: false}, [%{date: ~D[2026-10-03], start_time: ~T[16:00:00], end_time: ~T[19:00:00]}])

aspire = fn id, title, ages, cohorts, sessions, link ->
  put!.(%{id: id, venue_id: 22, title: title, kind: "class", ocf: nil, cohorts: Enum.map(cohorts, &elem(&1, 0)), timezone: tz, location_kind: "venue", summary: title, schedule_kind: "course", start_date: hd(Enum.map(sessions, & &1.date)), end_date: List.last(Enum.map(sessions, & &1.date)), audience: ["youth"], ages: ages, link: link, link_kind: "registration", confidence: "confirmed", caveat: nil, sources: [link], checked_on: ~D[2026-09-06], published: false}, sessions)
end
aspire_from = fn id, title, ages, cohorts, link -> aspire.(id, title, ages, cohorts, ExplicitBatch3Dates.sessions(cohorts), link) end

# Saved gym-22 calendars: exact cohort rows and holiday skips, not recurrence expansion.
aspire_from.(215, "Buffalos Climbing Program — Fall 2026", "Ages 6–7.", [
  {"Thursday — Sep 17 cohort", ~T[16:30:00], ~T[17:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15)},
  {"Saturday — Sep 19 cohort", ~T[10:00:00], ~T[11:00:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-17 2026-10-24)},
  {"Sunday — Sep 20 cohort", ~T[11:15:00], ~T[12:15:00], ~w(2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25)},
  {"Thursday — Oct 22 cohort", ~T[16:30:00], ~T[17:30:00], ~w(2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19)},
  {"Saturday — Oct 31 cohort", ~T[10:00:00], ~T[11:00:00], ~w(2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28)},
  {"Sunday — Nov 1 cohort", ~T[11:15:00], ~T[12:15:00], ~w(2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29)}
], "https://app.rockgympro.com/b/?bo=b14c06586a1d451d90ba44b3c2c115ca")

aspire_from.(216, "Rattlesnakes Climbing Program — Fall 2026", "Ages 8–10.", [
  {"Tuesday", ~T[17:30:00], ~T[18:30:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17)},
  {"Thursday", ~T[17:30:00], ~T[18:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19)},
  {"Saturday", ~T[11:15:00], ~T[12:15:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28)},
  {"Sunday", ~T[10:00:00], ~T[11:00:00], ~w(2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29)}
], "https://app.rockgympro.com/b/?bo=ac3ca75f5ba44f34a30a1a5c15e3033a")

aspire_from.(217, "Kelsos Climbing Program — Fall 2026", "Ages 11–14.", [
  {"Tuesday", ~T[19:00:00], ~T[20:30:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17)},
  {"Thursday", ~T[19:00:00], ~T[20:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19)}
], "https://app.rockgympro.com/b/?bo=5c04f1fafc6b48a9b73bf1f1464709f1")

aspire_from.(218, "Youth Adaptive Climbing — Fall 2026", "Ages 6–13.", [{"Sundays", ~T[17:00:00], ~T[19:00:00], ~w(2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01)}], "https://app.rockgympro.com/b/?bo=6c3eff4068bf421a8af4436f1cb1e26c")

aspire_from.(219, "Teen Night — Fall 2026 climbing series", "Age range not stated in saved offering.", [{"Fridays", ~T[17:30:00], ~T[19:30:00], ~w(2026-09-18 2026-09-25 2026-10-02 2026-10-16 2026-10-23 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27)}], "https://app.rockgympro.com/b/?bo=620d3458de284c4f9d7eabb02635ddf7")

aspire_from.(221, "League of Ninjas 2.0 — Fall 2026", "Ages 8–10.", [
  {"Thursday", ~T[18:00:00], ~T[19:00:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19)},
  {"Saturday", ~T[11:30:00], ~T[12:30:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28)},
  {"Sunday", ~T[10:15:00], ~T[11:15:00], ~w(2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29)}
], "https://app.rockgympro.com/b/?bo=350ead321acd47e89714cf77c05fdc18")

aspire_from.(222, "League of Ninjas 3.0 — Fall 2026", "Ages 11–14.", [{"Tuesdays", ~T[17:15:00], ~T[18:45:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17)}], "https://app.rockgympro.com/b/?bo=e3d642737a304e1f8f9bd4fb49665727")

put!.(%{id: 223, venue_id: 22, title: "Adaptive Climbing Try-Us-Out Nights", kind: "class", ocf: nil, cohorts: [], timezone: tz, location_kind: "venue", summary: "Monthly adaptive climbing evenings for all ages and skill levels.", schedule_kind: "recurring", recurrence: "monthly", weekday: 7, month_week: -1, start_time: ~T[17:00:00], audience: ["adaptive"], ages: "All ages.", link: "https://app.rockgympro.com/b/?bo=2da17faea5f84ffe8be7f35b41ee17f6", link_kind: "registration", confidence: "confirmed", caveat: nil, sources: ["https://www.aspireclimbing.com/whitby", "https://www.aspireclimbing.com/adaptiveclimbing", "https://app.rockgympro.com/b/?bo=2da17faea5f84ffe8be7f35b41ee17f6"], checked_on: ~D[2026-09-06], published: false}, :preserve)

put!.(%{id: 224, venue_id: 22, title: "Competitive Climbing Team — 2026/2027 season", kind: "class", ocf: nil, cohorts: [], timezone: tz, location_kind: "venue", summary: "Competitive youth climbing training for local through national events.", schedule_kind: "unscheduled", audience: ["youth"], ages: nil, link: "https://app.rockgympro.com/b/?bw=a696d72cca474d99a3aae7ddc27fc283", link_kind: "registration", confidence: "confirmed", caveat: nil, sources: ["https://app.rockgympro.com/b/?bw=a696d72cca474d99a3aae7ddc27fc283"], checked_on: ~D[2026-09-06], published: false}, [])

IO.puts("explicit batch 3.1 complete")
