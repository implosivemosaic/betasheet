alias ClimbOntario.Catalogue.Import
alias ClimbOntario.Repo
venue = fn source_id -> Repo.get_by!(ClimbOntario.Catalogue.Venue, source_gym_id: source_id).id end
put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, _} -> :ok
    {:error, cs} -> raise "repair #{attrs.id}: #{inspect(cs.errors)}"
  end
end

dates = fn list -> Enum.map(list, &Date.from_iso8601!/1) end
wed10 = dates.(~w[2026-09-09 2026-09-16 2026-09-23 2026-09-30 2026-10-07 2026-10-14 2026-10-21 2026-10-28 2026-11-04 2026-11-11])
mon10 = dates.(~w[2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26 2026-11-02 2026-11-09 2026-11-16 2026-11-23])
tue10 = dates.(~w[2026-09-08 2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10])
thu10 = dates.(~w[2026-09-10 2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12])

# 19: the handoff identifies 12 actual SOHR/Nemos cohorts and 120 rows.
cohorts19 = [
  {"SOHR1 Wednesday", wed10, ~T[16:30:00], ~T[17:30:00]}, {"SOHR1 Monday", mon10, ~T[16:30:00], ~T[17:30:00]},
  {"SOHR2 Wednesday", wed10, ~T[17:45:00], ~T[18:45:00]}, {"SOHR2 Monday", mon10, ~T[17:45:00], ~T[18:45:00]},
  {"SOHR3 Tuesday", tue10, ~T[19:45:00], ~T[20:45:00]}, {"SOHR3 Wednesday", wed10, ~T[19:00:00], ~T[20:00:00]},
  {"Nemos Tuesday 16:00", tue10, ~T[16:00:00], ~T[17:00:00]}, {"Nemos Tuesday 17:15", tue10, ~T[17:15:00], ~T[18:15:00]},
  {"Nemos Tuesday 18:30", tue10, ~T[18:30:00], ~T[19:30:00]}, {"Nemos Thursday 16:00", thu10, ~T[16:00:00], ~T[17:00:00]},
  {"Nemos Thursday 17:15", thu10, ~T[17:15:00], ~T[18:15:00]}, {"Nemos Thursday 18:30", thu10, ~T[18:30:00], ~T[19:30:00]}
]
put!.(%{id: 19, venue_id: venue.(27), title: "School of Hard Rock — Fall 2026", kind: "class", cohorts: Enum.map(cohorts19, &elem(&1, 0)),
  summary: "Youth climbing and climbing/ninja programs for ages 4 and older.", schedule_kind: "course", start_date: ~D[2026-09-08], end_date: ~D[2026-11-23], timezone: "America/Toronto",
  audience: ["youth"], ages: "Ages 4+, grouped by program level", link: "https://portal.aspireclimbing.com/milton/n/youth-programs", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/n/youth-programs", "https://www.aspireclimbing.com/milton", "https://www.aspireclimbing.com/climbing-programs", "https://portal.aspireclimbing.com/milton/programs/buffalos-ages-6-8", "https://portal.aspireclimbing.com/milton/programs/rattlesnakes-ages-9-10", "https://portal.aspireclimbing.com/milton/programs/kelsos-ages-11", "https://portal.aspireclimbing.com/milton/programs/league-of-nemos-ages-4-5"], checked_on: ~D[2026-09-06], published: false},
  Enum.flat_map(cohorts19, fn {name, ds, st, et} -> Enum.map(ds, &%{date: &1, cohort: name, start_time: st, end_time: et}) end))

# 66: three actual heats; source pages disagree only on the noon versus 12:15 end.
put!.(%{id: 66, venue_id: venue.(33), title: "Junction Journey Ep.12: Tour de Junction", kind: "competition", ocf: false, cohorts: ["Heat 1", "Heat 2", "Heat 3"],
  summary: "A team race combining climbing and non-climbing challenges for teams of 3–4.", schedule_kind: "one_off", start_date: ~D[2026-09-26], end_date: ~D[2026-09-26], timezone: "America/Toronto",
  audience: [], link: "https://www.junctionclimbing.com/tour-de-junction", link_kind: "event", confidence: "check",
  caveat: "Published sources differ on whether the final heat ends at noon or 12:15 p.m.",
  sources: ["https://www.junctionclimbing.com/event-database", "https://www.junctionclimbing.com/tour-de-junction", "https://app.rockgympro.com/b/?bo=ab92da35e6ce4c15aeb34de016d57f19", "https://www.instagram.com/climbjunction/p/DaV3jBGCY33/"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-26], cohort: "Heat 1", start_time: ~T[10:00:00], end_time: ~T[10:45:00]},
   %{date: ~D[2026-09-26], cohort: "Heat 2", start_time: ~T[10:45:00], end_time: ~T[11:30:00]},
   %{date: ~D[2026-09-26], cohort: "Heat 3", start_time: ~T[11:30:00], end_time: nil}])

# 70: September round only; November 282 is a separate listing and is not mixed in.
mon70 = dates.(~w[2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26 2026-11-02 2026-11-09])
wed70 = dates.(~w[2026-09-16 2026-09-23 2026-09-30 2026-10-07 2026-10-14 2026-10-21 2026-10-28 2026-11-04 2026-11-11])
tue70 = dates.(~w[2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10])
thu70 = dates.(~w[2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12])
cohorts70 = [
  {"Alpine Approach Monday", mon70, ~T[16:15:00], ~T[17:15:00]}, {"Alpine Approach Wednesday", wed70, ~T[16:15:00], ~T[17:15:00]},
  {"Alpine Crag Monday", mon70, ~T[17:25:00], ~T[18:25:00]}, {"Alpine Crag Wednesday", wed70, ~T[17:25:00], ~T[18:25:00]},
  {"Alpine Crux Monday", mon70, ~T[18:35:00], ~T[19:50:00]}, {"Alpine Crux Wednesday", wed70, ~T[18:35:00], ~T[19:50:00]},
  {"Alpine Anchors Monday", mon70, ~T[20:00:00], ~T[21:30:00]}, {"Alpine Anchors Wednesday", wed70, ~T[20:00:00], ~T[21:30:00]},
  {"Beta 1 Tuesday", tue70, ~T[16:15:00], ~T[17:15:00]}, {"Beta 1 Thursday", thu70, ~T[16:15:00], ~T[17:15:00]},
  {"Beta 2 Tuesday", tue70, ~T[17:25:00], ~T[18:25:00]}, {"Beta 2 Thursday", thu70, ~T[17:25:00], ~T[18:25:00]},
  {"Beta 3 Tuesday", tue70, ~T[18:35:00], ~T[19:50:00]}, {"Beta 3 Thursday", thu70, ~T[18:35:00], ~T[19:50:00]},
  {"Beta 4 Tuesday", tue70, ~T[20:00:00], ~T[21:30:00]}, {"Beta 4 Thursday", thu70, ~T[20:00:00], ~T[21:30:00]}
]
put!.(%{id: 70, venue_id: venue.(32), title: "Nine-Week Youth Programs — Fall 2026", kind: "class", cohorts: Enum.map(cohorts70, &elem(&1, 0)),
  summary: "Nine-week youth climbing programs for ages 6 and older across Alpine and Beta levels.", schedule_kind: "course", start_date: ~D[2026-09-14], end_date: ~D[2026-11-12], timezone: "America/Toronto",
  audience: ["youth"], ages: "Ages 6+", link: "https://guelphgrotto.rphq.com/guelphgrotto/n/youth-programs", link_kind: "registration", confidence: "confirmed",
  sources: ["https://guelphgrotto.rphq.com/guelphgrotto/n/youth-programs", "https://www.instagram.com/guelphgrotto/reel/Dcw9Xm3E8WI/", "https://www.guelphgrotto.com/indoor-youth-activities", "https://guelphgrotto.rphq.com/guelphgrotto/programs/approach-6-8yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/crag-8-10yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/crux-10-13yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/anchors-13yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-1", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-2", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-3", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-4"], checked_on: ~D[2026-09-06], published: false},
  Enum.flat_map(cohorts70, fn {name, ds, st, et} -> Enum.map(ds, &%{date: &1, cohort: name, start_time: st, end_time: et}) end))

# 281: exactly the 19 inspected starts; Sep 7 is retained with a closure caveat.
starts281 = [{~D[2026-09-07], ~T[16:15:00], ~T[18:15:00]}, {~D[2026-09-07], ~T[20:00:00], ~T[22:00:00]},
  {~D[2026-09-08], ~T[12:15:00], ~T[14:15:00]}, {~D[2026-09-08], ~T[14:30:00], ~T[16:30:00]}, {~D[2026-09-08], ~T[20:00:00], ~T[22:00:00]},
  {~D[2026-09-09], ~T[12:15:00], ~T[14:15:00]}, {~D[2026-09-09], ~T[14:30:00], ~T[16:30:00]}, {~D[2026-09-09], ~T[20:00:00], ~T[22:00:00]},
  {~D[2026-09-10], ~T[12:15:00], ~T[14:15:00]}, {~D[2026-09-10], ~T[14:30:00], ~T[16:30:00]}, {~D[2026-09-10], ~T[20:00:00], ~T[22:00:00]},
  {~D[2026-09-11], ~T[16:15:00], ~T[18:15:00]}, {~D[2026-09-11], ~T[20:30:00], ~T[22:30:00]},
  {~D[2026-09-12], ~T[10:00:00], ~T[12:00:00]}, {~D[2026-09-12], ~T[12:30:00], ~T[14:30:00]}, {~D[2026-09-12], ~T[15:00:00], ~T[17:00:00]},
  {~D[2026-09-13], ~T[10:00:00], ~T[12:00:00]}, {~D[2026-09-13], ~T[12:30:00], ~T[14:30:00]}, {~D[2026-09-13], ~T[15:00:00], ~T[17:00:00]}]
put!.(%{id: 281, venue_id: venue.(28), title: "Indoor Rock 101 — current lessons", kind: "class", cohorts: [], summary: "Two-hour introductory top-rope safety and belay lessons for ages 14 and older.", schedule_kind: "recurring", timezone: "America/Toronto", audience: ["youth", "adult"], ages: "Ages 14+", link: "https://app.rockgympro.com/b/?bo=7f2770f43de64e71a2e7f247f1f2b4bb", link_kind: "registration", confidence: "check", caveat: "September 7 calendar entries conflict with the published Labour Day closure notice.", sources: ["https://www.gravityhamilton.com/climbing", "https://app.rockgympro.com/b/?bw=14b7b3b08481405ba5fb7ba88b9de8de", "https://app.rockgympro.com/b/?bo=7f2770f43de64e71a2e7f247f1f2b4bb", "https://www.instagram.com/gravityhamilton/p/Dc4cegpJxYp/"], checked_on: ~D[2026-09-06], published: false}, Enum.map(starts281, fn {d, st, et} -> %{date: d, start_time: st, end_time: et} end))

# 312: one official OCF para event, one date, no invented category sessions.
put!.(%{id: 312, venue_id: venue.(33), title: "OCF Para Climbing Competition #3 — 2027-01-09", kind: "competition", ocf: true, cohorts: [], summary: "OCF para climbing competition for adaptive climbers.", schedule_kind: "one_off", start_date: ~D[2027-01-09], end_date: ~D[2027-01-09], timezone: "America/Toronto", audience: ["adaptive"], link: "https://www.climbontario.ca/events/ocf-para-climbing-competition-3", link_kind: "event", confidence: "confirmed", caveat: nil, sources: ["https://www.climbontario.ca/events/ocf-para-climbing-competition-3", "https://www.climbontario.ca/news/ocf-2026-27-competition-season", "https://www.climbontario.ca/news/ocf-launches-para-climbing-3-competition-series-for-2026-27-season"], checked_on: ~D[2026-09-07], published: false}, [%{date: ~D[2027-01-09], start_time: nil, end_time: nil, timezone: nil}])
IO.puts("repaired IDs 19, 66, 70, 281, 312")
