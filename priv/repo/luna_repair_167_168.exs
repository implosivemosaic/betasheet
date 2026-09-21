alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn a, s -> case Import.put_listing(a, s) do {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences"); {:error, c} -> IO.inspect(c); raise "repair failed" end end
o = fn d, c, s, e -> %{date: d, cohort: c, start_time: s, end_time: e, timezone: tz} end
src = fn u -> %{sources: u, checked_on: ~D[2026-09-06], published: false, confidence: "check"} end
v = %{timezone: tz, venue_id: 44, location_kind: "venue", published: false}
weekdates = fn first, last, weekday -> Date.range(first, last) |> Enum.filter(&(Date.day_of_week(&1) == weekday)) end
specs = [{"Tuesday 8-week", 2, ~D[2026-09-08], ~D[2026-10-27], ~T[16:30:00], ~T[18:00:00]}, {"Tuesday 16-week", 2, ~D[2026-09-08], ~D[2026-12-15], ~T[16:30:00], ~T[18:00:00]}, {"Wednesday 8-week", 3, ~D[2026-09-09], ~D[2026-10-28], ~T[16:30:00], ~T[18:00:00]}, {"Wednesday 16-week", 3, ~D[2026-09-09], ~D[2026-12-16], ~T[16:30:00], ~T[18:00:00]}, {"Thursday 8-week", 4, ~D[2026-09-10], ~D[2026-10-29], ~T[16:30:00], ~T[18:00:00]}, {"Thursday 16-week", 4, ~D[2026-09-10], ~D[2026-12-17], ~T[16:30:00], ~T[17:30:00]}, {"Friday 8-week", 5, ~D[2026-09-11], ~D[2026-10-30], ~T[16:30:00], ~T[18:00:00]}, {"Friday 16-week", 5, ~D[2026-09-11], ~D[2026-12-18], ~T[16:30:00], ~T[18:00:00]}]
sessions = Enum.flat_map(specs, fn {n, wd, first, last, s, e} -> Enum.map(weekdates.(first, last, wd), &o.(&1, n, s, e)) end)
put!.(Map.merge(v, %{id: 167, title: "Spider Monkeys and Chimps — September 2026", kind: "class", summary: "Youth climbing classes for ages 6–12 combining top-rope, bouldering, games and movement skills.", schedule_kind: "course", cohorts: Enum.map(specs, fn {n,_,_,_,_,_}->n end), start_date: ~D[2026-09-08], end_date: ~D[2026-12-18], audience: ["youth"], ages: "6–12", schedule_note: "Eight weekday enrolment options are shown with their confirmed 8- or 16-week calendars; Thursday's long option ends at 17:30. Overlapping enrolment options are not separate classes.", link: "https://www.rockandrope.com/youth", link_kind: "event"}) |> Map.merge(src.( ["https://www.rockandrope.com/youth"])), sessions)

fridays = [~D[2026-09-11], ~D[2026-09-18], ~D[2026-09-25], ~D[2026-10-02], ~D[2026-10-09], ~D[2026-10-16], ~D[2026-10-23], ~D[2026-10-30]]
sessions168 = Enum.map(fridays, &o.(&1, "Friday cohort", ~T[18:00:00], ~T[20:00:00]))
put!.(Map.merge(v, %{id: 168, title: "Teen Climbing Club — September 2026", kind: "class", summary: "Weekly teen climbing and social club for ages 12–17.", schedule_kind: "recurring", cohorts: ["Friday cohort"], audience: ["youth"], ages: "12–17", schedule_note: "Eight Friday dates are confirmed. Sunday and combined Sunday–Friday offerings are advertised, but their remaining calendar dates were not individually verified.", link: "https://www.rockandrope.com/youth", link_kind: "event"}) |> Map.merge(src.( ["https://www.rockandrope.com/youth"])), sessions168)
