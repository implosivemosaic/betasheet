alias ClimbOntario.Catalogue.Import

put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences")
    {:error, cs} -> IO.inspect(cs, label: "REPAIR FAILED #{attrs[:id]}"); raise "repair failed"
  end
end

tz = "America/Toronto"

# Reach 115: all 11 saved cohorts and all 132 explicitly listed dates.
cohorts_115 = [
  {"Ages 4–6 — Tuesday", ~T[16:00:00], ~T[17:30:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01)},
  {"Ages 4–6 — Thursday", ~T[16:00:00], ~T[17:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03)},
  {"Ages 4–6 — Saturday", ~T[13:30:00], ~T[15:00:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-10 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28 2026-12-05)},
  {"Ages 4–6 — Sunday", ~T[09:30:00], ~T[11:00:00], ~w(2026-09-20 2026-09-27 2026-10-04 2026-10-11 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29 2026-12-06)},
  {"Ages 7–10 — Tuesday", ~T[16:00:00], ~T[17:30:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01)},
  {"Ages 7–10 — Thursday", ~T[16:00:00], ~T[17:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03)},
  {"Ages 7–10 — Saturday", ~T[13:30:00], ~T[15:00:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-10 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28 2026-12-05)},
  {"Ages 7–10 — Sunday", ~T[09:30:00], ~T[11:00:00], ~w(2026-09-20 2026-09-27 2026-10-04 2026-10-11 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29 2026-12-06)},
  {"Ages 11–13 — Tuesday", ~T[17:30:00], ~T[19:30:00], ~w(2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01)},
  {"Ages 11–13 — Thursday", ~T[17:30:00], ~T[19:30:00], ~w(2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03)},
  {"Ages 14–17 — Friday", ~T[18:30:00], ~T[20:30:00], ~w(2026-09-18 2026-09-25 2026-10-02 2026-10-09 2026-10-16 2026-10-23 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04)}
]
sessions_115 = Enum.flat_map(cohorts_115, fn {cohort, start_time, end_time, dates} -> Enum.map(dates, &%{date: &1, cohort: cohort, start_time: start_time, end_time: end_time}) end)
put!.(%{id: 115, venue_id: 21, title: "Youth Recreational Lessons — Session 1 Fall 2026", kind: "class", ocf: nil, cohorts: Enum.map(cohorts_115, &elem(&1, 0)), timezone: tz, location_kind: "venue", summary: "Age-grouped weekly climbing lessons for youth ages 4–17.", schedule_kind: "course", start_date: ~D[2026-09-15], end_date: ~D[2026-12-06], audience: ["youth"], ages: "Ages 4–17.", link: "https://reachindoorclimbing.ca/youth-lessons", link_kind: "event", confidence: "confirmed", caveat: nil, sources: ["https://reachindoorclimbing.ca/youth-lessons", "https://www.instagram.com/reachindoorclimbing/p/DcjiZMQsT-p/", "https://app.rockgympro.com/b/?bo=0b5f49c3fd66440e8be9676469774a83", "https://app.rockgympro.com/b/?bo=6f7afc5e78b642cca995beac172742fe"], checked_on: ~D[2026-09-06], published: false}, sessions_115)

# Oasis 26: 32 cohorts (four streams x eight day/time groups), 142 rows per stream.
days_26 = [
  {"Monday", ~T[16:00:00], ~T[18:00:00], ~w(2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26 2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30 2026-12-07 2026-12-14 2027-01-04 2027-01-11 2027-01-18 2027-01-25)},
  {"Tuesday", ~T[15:45:00], ~T[17:30:00], ~w(2026-09-08 2026-09-15 2026-09-22 2026-09-29 2026-10-06 2026-10-13 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01 2026-12-08 2026-12-15 2027-01-05 2027-01-12 2027-01-19 2027-01-26)},
  {"Wednesday", ~T[15:45:00], ~T[17:30:00], ~w(2026-09-09 2026-09-16 2026-09-23 2026-09-30 2026-10-07 2026-10-14 2026-10-21 2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02 2026-12-09 2026-12-16 2027-01-06 2027-01-13 2027-01-20 2027-01-27)},
  {"Thursday", ~T[16:00:00], ~T[17:45:00], ~w(2026-09-10 2026-09-17 2026-09-24 2026-10-01 2026-10-08 2026-10-15 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03 2026-12-10 2026-12-17 2027-01-07 2027-01-14 2027-01-21 2027-01-28)},
  {"Saturday early", ~T[09:00:00], ~T[10:45:00], ~w(2026-09-12 2026-09-19 2026-09-26 2026-10-03 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28 2026-12-05 2026-12-12 2027-01-09 2027-01-16 2027-01-23 2027-01-30)},
  {"Saturday late", ~T[11:15:00], ~T[13:15:00], ~w(2026-09-12 2026-09-19 2026-09-26 2026-10-03 2026-10-17 2026-10-24 2026-10-31 2026-11-07 2026-11-14 2026-11-21 2026-11-28 2026-12-05 2026-12-12 2027-01-09 2027-01-16 2027-01-23 2027-01-30)},
  {"Sunday early", ~T[09:00:00], ~T[11:00:00], ~w(2026-09-13 2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29 2026-12-06 2026-12-13 2027-01-10 2027-01-17 2027-01-24 2027-01-31)},
  {"Sunday late", ~T[11:15:00], ~T[13:15:00], ~w(2026-09-13 2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29 2026-12-06 2026-12-13 2027-01-10 2027-01-17 2027-01-24 2027-01-31)}
]
# Saved evidence gives different time mappings for Pebble/Rock versus Rec/Dev.
stream_times_26 = %{
  "Pebble 6–7" => %{"Monday" => {~T[16:00:00], ~T[17:45:00]}, "Tuesday" => {~T[15:45:00], ~T[17:30:00]}, "Wednesday" => {~T[15:45:00], ~T[17:30:00]}, "Thursday" => {~T[16:00:00], ~T[17:45:00]}, "Saturday early" => {~T[09:00:00], ~T[10:45:00]}, "Saturday late" => {~T[11:00:00], ~T[12:45:00]}, "Sunday early" => {~T[09:00:00], ~T[10:45:00]}, "Sunday late" => {~T[11:00:00], ~T[12:45:00]}},
  "Rock Club 8–10" => %{"Monday" => {~T[16:00:00], ~T[17:45:00]}, "Tuesday" => {~T[15:45:00], ~T[17:30:00]}, "Wednesday" => {~T[15:45:00], ~T[17:30:00]}, "Thursday" => {~T[16:00:00], ~T[17:45:00]}, "Saturday early" => {~T[09:00:00], ~T[10:45:00]}, "Saturday late" => {~T[11:00:00], ~T[12:45:00]}, "Sunday early" => {~T[09:00:00], ~T[10:45:00]}, "Sunday late" => {~T[11:00:00], ~T[12:45:00]}},
  "Recreational Team 11–13" => %{"Monday" => {~T[16:00:00], ~T[18:00:00]}, "Tuesday" => {~T[16:00:00], ~T[18:00:00]}, "Wednesday" => {~T[16:00:00], ~T[18:00:00]}, "Thursday" => {~T[16:00:00], ~T[18:00:00]}, "Saturday early" => {~T[09:00:00], ~T[11:00:00]}, "Saturday late" => {~T[11:15:00], ~T[13:15:00]}, "Sunday early" => {~T[09:00:00], ~T[11:00:00]}, "Sunday late" => {~T[11:15:00], ~T[13:15:00]}},
  "Development Team 13–17" => %{"Monday" => {~T[16:00:00], ~T[18:00:00]}, "Tuesday" => {~T[16:00:00], ~T[18:00:00]}, "Wednesday" => {~T[16:00:00], ~T[18:00:00]}, "Thursday" => {~T[16:00:00], ~T[18:00:00]}, "Saturday early" => {~T[09:00:00], ~T[11:00:00]}, "Saturday late" => {~T[11:15:00], ~T[13:15:00]}, "Sunday early" => {~T[09:00:00], ~T[11:00:00]}, "Sunday late" => {~T[11:15:00], ~T[13:15:00]}}
}
cohorts_26 = for stream <- Map.keys(stream_times_26), {day, _old_st, _old_et, dates} <- days_26, {st, et} = Map.fetch!(stream_times_26, stream)[day], do: {"#{stream} — #{day}", st, et, dates}
sessions_26 = Enum.flat_map(cohorts_26, fn {cohort, st, et, dates} -> Enum.map(dates, &%{date: &1, cohort: cohort, start_time: st, end_time: et}) end)
put!.(%{id: 26, venue_id: 6, title: "School of Rock — Fall 2026 semester", kind: "class", ocf: nil, cohorts: Enum.map(cohorts_26, &elem(&1, 0)), timezone: tz, location_kind: "venue", summary: "Four youth climbing streams with age-grouped weekly cohorts from September through January.", schedule_kind: "course", start_date: ~D[2026-09-08], end_date: ~D[2027-01-31], audience: ["youth"], ages: "Ages 6–17.", link: "https://www.rockoasis.com/schoolofrock", link_kind: "event", confidence: "confirmed", caveat: nil, sources: ["https://www.rockoasis.com/schoolofrock", "https://app.rockgympro.com/b/?bo=26b6548fe3f54d2e96b2ecffc6082436" , "https://app.rockgympro.com/b/?bo=7e12047bf79f4ec8b51681cf4405bd5d", "https://app.rockgympro.com/b/?bo=c2f918f2d8b54c07b688c8966a2f675c", "https://app.rockgympro.com/b/?bo=f08aeabfafda4e90b3347472a7b9d962"], checked_on: ~D[2026-09-06], published: false}, sessions_26)

repair_hub = fn {id, title, ages, cohorts, sessions, url, checked} ->
  put!.(%{id: id, venue_id: 14, title: title, kind: "class", ocf: nil, cohorts: cohorts, timezone: tz, location_kind: "venue", summary: "Age-grouped youth climbing lessons with weekly coached sessions.", schedule_kind: "course", start_date: ~D[2026-09-14], end_date: ~D[2026-10-26], audience: ["youth"], ages: ages, link: url, link_kind: "registration", confidence: "confirmed", caveat: nil, sources: [url], checked_on: checked, published: false}, sessions)
end
hub = fn {names, st, et, dates} -> Enum.map(dates, &%{date: &1, cohort: names, start_time: st, end_time: et}) end
hub_dates = [
  {"Monday", ~T[17:30:00], ~T[19:00:00], ~w(2026-09-14 2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26)},
  {"Saturday", ~T[11:30:00], ~T[13:00:00], ~w(2026-09-19 2026-09-26 2026-10-03 2026-10-10 2026-10-17 2026-10-24)}
]
repair_hub.({260, "Dragon — September–October 2026", "Ages 7–9.", ["Monday", "Saturday"], Enum.flat_map(hub_dates, &hub.(&1)), "https://app.rockgympro.com/b/?bo=d5fae0bb18f14f27858d5f84c9984a6d", ~D[2026-09-06]})

put!.(%{id: 233, venue_id: 6, title: "Bulges & Boulders — September 2026 Rock Oasis meetups", kind: "social", ocf: nil, cohorts: [], timezone: tz, location_kind: "venue", summary: "Queer-inclusive community climbing meetups for all levels.", schedule_kind: "recurring", start_date: ~D[2026-09-08], audience: ["queer"], link: "https://www.instagram.com/bulgesandboulders/p/DcvwNu4Ee66/", link_kind: "event", confidence: "confirmed", caveat: nil, sources: ["https://www.instagram.com/bulgesandboulders/p/DcvwNu4Ee66/"], checked_on: ~D[2026-09-06], published: false}, Enum.map(~w(2026-09-08 2026-09-15 2026-09-22), &%{date: &1, start_time: ~T[18:00:00], end_time: ~T[20:30:00]}) )

put!.(%{id: 302, venue_id: 21, title: "OCF Para Climbing Competition #1 — 2026-09-26", kind: "competition", ocf: true, cohorts: [], timezone: tz, location_kind: "venue", summary: "Official OCF para climbing competition for adaptive climbers.", schedule_kind: "one_off", start_date: ~D[2026-09-26], end_date: ~D[2026-09-26], audience: ["adaptive"], ages: "Para climbers.", link: "https://www.climbontario.ca/events/ocf-para-climbing-competition-1", link_kind: "event", confidence: "confirmed", caveat: nil, sources: ["https://www.climbontario.ca/events/ocf-para-climbing-competition-1", "https://www.climbontario.ca/news/ocf-2026-27-competition-season", "https://www.climbontario.ca/news/ocf-launches-para-climbing-3-competition-series-for-2026-27-season"], checked_on: ~D[2026-09-07], published: false}, [%{date: ~D[2026-09-26]}])

IO.puts("five repairs complete")
