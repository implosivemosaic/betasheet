alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences")
    {:error, c} -> IO.inspect(c); raise "repair failed"
  end
end
o = fn d, cohort, s, e -> %{date: d, cohort: cohort, start_time: s, end_time: e, timezone: tz} end
src = fn urls -> %{sources: urls, checked_on: ~D[2026-09-06], confidence: "confirmed", published: false} end
weekday_dates = fn first, last, weekday, skips -> Date.range(first, last) |> Enum.filter(&(Date.day_of_week(&1) == weekday and &1 not in skips)) end

cohorts52 = [
  {"Astro 4–6 Monday", 1, ~T[16:15:00], ~T[17:45:00], ~D[2026-09-28], ~D[2026-11-23], [~D[2026-10-12]]},
  {"Voyagers 13–16 Monday", 1, ~T[18:00:00], ~T[20:00:00], ~D[2026-09-28], ~D[2026-11-23], [~D[2026-10-12]]},
  {"Jr Challengers 7–11 Tuesday", 2, ~T[16:15:00], ~T[18:15:00], ~D[2026-09-29], ~D[2026-11-17], []},
  {"Sr Challengers 12–16 Tuesday", 2, ~T[18:30:00], ~T[20:30:00], ~D[2026-09-29], ~D[2026-11-17], []},
  {"Jr Rovers 7–10 Wednesday", 3, ~T[16:15:00], ~T[17:45:00], ~D[2026-09-30], ~D[2026-11-18], []},
  {"Sr Rovers 11–13 Wednesday", 3, ~T[18:00:00], ~T[20:00:00], ~D[2026-09-30], ~D[2026-11-18], []},
  {"Jr Challengers Thursday", 4, ~T[16:15:00], ~T[18:15:00], ~D[2026-10-01], ~D[2026-11-19], []},
  {"Sr Challengers Thursday", 4, ~T[18:30:00], ~T[20:30:00], ~D[2026-10-01], ~D[2026-11-19], []},
  {"Sr Rovers Friday", 5, ~T[16:15:00], ~T[18:15:00], ~D[2026-10-02], ~D[2026-11-20], []},
  {"Voyagers Friday", 5, ~T[18:30:00], ~T[20:30:00], ~D[2026-10-02], ~D[2026-11-20], []},
  {"Astro Saturday", 6, ~T[10:30:00], ~T[12:00:00], ~D[2026-10-03], ~D[2026-11-21], []},
  {"Jr Rovers Saturday", 6, ~T[12:30:00], ~T[14:00:00], ~D[2026-10-03], ~D[2026-11-21], []},
  {"Sr Rovers Saturday", 6, ~T[14:30:00], ~T[16:30:00], ~D[2026-10-03], ~D[2026-11-21], []}
]
sessions52 = Enum.flat_map(cohorts52, fn {name, weekday, s, e, first, last, skips} -> Enum.map(weekday_dates.(first, last, weekday, skips), &o.(&1, name, s, e)) end)
put!.(%{id: 52, venue_id: 28, title: "Youth Programs — Fall 2026", kind: "class", timezone: tz, location_kind: "venue", summary: "Weekly youth climbing programmes for ages 4–16 across Astro, Challengers, Rovers and Voyagers groups.", schedule_kind: "course", cohorts: Enum.map(cohorts52, fn {n,_,_,_,_,_,_} -> n end), start_date: ~D[2026-09-28], end_date: ~D[2026-11-23], audience: ["youth"], ages: "4–16", schedule_note: "Thirteen named cohorts have eight confirmed sessions each; the October 12 closure and November 23 Monday makeup are preserved.", link: "https://www.gravityhamilton.com/climbing", link_kind: "event"} |> Map.merge(src.(["https://www.gravityhamilton.com/climbing"])), sessions52)

session_dates = fn weekday ->
  [
    weekday_dates.(~D[2026-09-15], ~D[2026-11-19], weekday, [~D[2026-10-12]]),
    weekday_dates.(~D[2026-11-24], ~D[2027-02-11], weekday, [~D[2026-12-21], ~D[2026-12-22], ~D[2026-12-23], ~D[2026-12-24], ~D[2026-12-25], ~D[2026-12-26], ~D[2026-12-27], ~D[2026-12-28], ~D[2026-12-29], ~D[2026-12-30], ~D[2026-12-31], ~D[2027-01-01], ~D[2027-01-02], ~D[2027-01-03]]),
    weekday_dates.(~D[2027-02-16], ~D[2027-04-29], weekday, [~D[2027-03-16], ~D[2027-03-17], ~D[2027-03-18]]),
    weekday_dates.(~D[2027-05-04], ~D[2027-06-24], weekday, [])
  ]
end
specs127 = [{"Tree Frog", 4, ~T[16:30:00], ~T[18:00:00]}, {"Koala Tuesday", 2, ~T[17:00:00], ~T[18:30:00]}, {"Koala Wednesday", 3, ~T[18:00:00], ~T[19:30:00]}, {"Mountain Goat Tuesday", 2, ~T[19:00:00], ~T[20:30:00]}, {"Mountain Goat Thursday", 4, ~T[18:30:00], ~T[20:00:00]}]
sessions127 = Enum.flat_map(specs127, fn {name, weekday, s, e} -> Enum.flat_map(session_dates.(weekday), &Enum.map(&1, fn d -> o.(d, name, s, e) end)) end)
put!.(%{id: 127, venue_id: 23, title: "Youth Lessons — Tree Frog, Koala and Mountain Goat 2026/2027", kind: "class", timezone: tz, location_kind: "venue", summary: "Weekly youth climbing lessons for ages 4–17 across four seasonal sessions.", schedule_kind: "course", cohorts: Enum.map(specs127, fn {n,_,_,_} -> n end), start_date: ~D[2026-09-15], end_date: ~D[2027-06-24], audience: ["youth"], ages: "4–17", schedule_note: "Four confirmed seasonal session blocks are shown; holiday and March-break gaps are preserved.", link: "https://www.rockandchalk.com/", link_kind: "event"} |> Map.merge(src.(["https://www.rockandchalk.com/"])), sessions127)

put!.(%{id: 128, venue_id: 23, title: "Learn The Ropes — Intro to Belay", kind: "class", timezone: tz, location_kind: "venue", summary: "Two-hour introductory belay lesson for climbers aged 12 and older.", schedule_kind: "recurring", schedule_note: "Seven September 12 appointment slots were inspected; earlier closed booking dates were not treated as available.", audience: ["adult"], ages: "12+", link: "https://www.rockandchalk.com/", link_kind: "registration"} |> Map.merge(src.(["https://www.rockandchalk.com/"])), Enum.map([~T[10:00:00],~T[11:00:00],~T[12:00:00],~T[13:00:00],~T[14:00:00],~T[15:00:00],~T[16:00:00]], &o.(~D[2026-09-12], nil, &1, Time.add(&1, 7200))))

for {id,title,summary} <- [{129,"Private and Semi-Private Climbing Lessons","Individualized climbing coaching by appointment."},{130,"Lead Climbing Course","Lead climbing and belaying course arranged across two or three days."}] do
  put!.(%{id: id, venue_id: 23, title: title, kind: "class", timezone: tz, location_kind: "venue", summary: summary, schedule_kind: "unscheduled", recurrence: nil, weekday: nil, audience: ["adult"], link: "https://www.rockandchalk.com/", link_kind: "event"} |> Map.merge(src.(["https://www.rockandchalk.com/"])), :preserve)
end

one_hour = [~T[10:00:00],~T[11:00:00],~T[12:00:00],~T[13:00:00],~T[14:00:00],~T[15:00:00],~T[16:00:00],~T[17:00:00]]
two_hour = [~T[10:00:00],~T[11:00:00],~T[12:00:00],~T[13:00:00],~T[15:00:00],~T[16:00:00]]
sessions131 = Enum.map(one_hour, &o.(~D[2026-09-12], "one-hour", &1, Time.add(&1, 3600))) ++ Enum.map(two_hour, &o.(~D[2026-09-12], "two-hour", &1, Time.add(&1, 7200)))
put!.(%{id: 131, venue_id: 23, title: "Climb Time — Staff-Assisted One or Two Hour Climb", kind: "class", timezone: tz, location_kind: "venue", summary: "Staff-assisted one- or two-hour climbing sessions for families, first-timers and climbers seeking extra guidance.", schedule_kind: "recurring", cohorts: ["one-hour", "two-hour"], schedule_note: "September 12 one- and two-hour starts are confirmed; later calendar dates were not individually checked.", audience: ["family", "adult"], link: "https://www.rockandchalk.com/", link_kind: "registration"} |> Map.merge(src.(["https://www.rockandchalk.com/"])), sessions131)
