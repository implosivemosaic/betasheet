alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences")
    {:error, c} -> IO.inspect(c); raise "repair failed"
  end
end
o = fn d, c, s, e -> %{date: d, cohort: c, start_time: s, end_time: e, timezone: tz} end
src = fn urls -> %{sources: urls, checked_on: ~D[2026-09-06], published: false, confidence: "confirmed"} end
winter_dates = fn weekday -> Date.range(~D[2026-11-23], ~D[2027-01-28]) |> Enum.filter(fn d -> Date.day_of_week(d) == weekday and d not in [~D[2026-12-21],~D[2026-12-22],~D[2026-12-23],~D[2026-12-24],~D[2026-12-25],~D[2026-12-26],~D[2026-12-27],~D[2026-12-28],~D[2026-12-29],~D[2026-12-30],~D[2026-12-31],~D[2027-01-01],~D[2027-01-02],~D[2027-01-03]] end) end

cohort_specs = [
  {"Alpine Approach 6–8 Monday", 1, ~T[16:15:00], ~T[17:15:00]}, {"Alpine Approach 6–8 Wednesday", 3, ~T[16:15:00], ~T[17:15:00]},
  {"Alpine Crag 8–10 Monday", 1, ~T[17:25:00], ~T[18:25:00]}, {"Alpine Crag 8–10 Wednesday", 3, ~T[17:25:00], ~T[18:25:00]},
  {"Alpine Crux 10–13 Monday", 1, ~T[18:35:00], ~T[19:50:00]}, {"Alpine Crux 10–13 Wednesday", 3, ~T[18:35:00], ~T[19:50:00]},
  {"Alpine Anchors 13+ Monday", 1, ~T[20:00:00], ~T[21:30:00]}, {"Alpine Anchors 13+ Wednesday", 3, ~T[20:00:00], ~T[21:30:00]},
  {"Beta 1 Tuesday", 2, ~T[16:15:00], ~T[17:15:00]}, {"Beta 1 Thursday", 4, ~T[16:15:00], ~T[17:15:00]},
  {"Beta 2 Tuesday", 2, ~T[17:25:00], ~T[18:25:00]}, {"Beta 2 Thursday", 4, ~T[17:25:00], ~T[18:25:00]},
  {"Beta 3 Tuesday", 2, ~T[18:35:00], ~T[19:50:00]}, {"Beta 3 Thursday", 4, ~T[18:35:00], ~T[19:50:00]},
  {"Beta 4 Tuesday", 2, ~T[20:00:00], ~T[21:30:00]}, {"Beta 4 Thursday", 4, ~T[20:00:00], ~T[21:30:00]}
]
winter = Enum.flat_map(cohort_specs, fn {name, weekday, s, e} -> Enum.map(winter_dates.(weekday), &o.(&1, name, s, e)) end)
put!.(Map.merge(%{id: 282, venue_id: 32, title: "Alpine and Beta Youth Programs — November 2026–January 2027", kind: "class", timezone: tz, location_kind: "venue", summary: "Eight-session youth climbing programmes with Alpine age groups and Beta progression levels.", schedule_kind: "course", cohorts: Enum.map(cohort_specs, fn {n,_,_,_}->n end), audience: ["youth"], ages: "Alpine ages 6–13+; Beta levels 1–4", schedule_note: "Sixteen named cohorts have eight confirmed sessions each; the December 21–January 3 holiday gap is preserved.", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/approach-6-8yrs", link_kind: "registration"}, src.(["https://guelphgrotto.rphq.com/guelphgrotto/programs/approach-6-8yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/crag-8-10yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/crux-10-13yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/anchors-13yrs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-1", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-2", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-3", "https://guelphgrotto.rphq.com/guelphgrotto/programs/level-4"])), winter)

put!.(Map.merge(%{id: 283, venue_id: 32, title: "Development Team Open House — September 2026", kind: "social", timezone: tz, location_kind: "venue", summary: "Low-pressure open house for ages 10–16 to meet coaches and explore the development team.", schedule_kind: "one_off", start_date: ~D[2026-09-13], end_date: ~D[2026-09-13], start_time: ~T[16:00:00], end_time: ~T[18:00:00], audience: ["youth"], ages: "10–16", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/development-team-open-house", link_kind: "registration"}, src.( ["https://guelphgrotto.rphq.com/guelphgrotto/programs/development-team-open-house"])), [o.(~D[2026-09-13], nil, ~T[16:00:00], ~T[18:00:00])])

rope_dates = [{~D[2026-09-09],~T[18:00:00],~T[20:00:00]},{~D[2026-09-10],~T[18:00:00],~T[20:00:00]},{~D[2026-09-12],~T[10:00:00],~T[12:00:00]},{~D[2026-09-16],~T[18:00:00],~T[20:00:00]},{~D[2026-09-17],~T[18:00:00],~T[20:00:00]},{~D[2026-09-23],~T[18:00:00],~T[20:00:00]},{~D[2026-09-24],~T[18:00:00],~T[20:00:00]},{~D[2026-09-26],~T[10:00:00],~T[12:00:00]},{~D[2026-09-30],~T[18:00:00],~T[20:00:00]}]
put!.(Map.merge(%{id: 284, venue_id: 32, title: "OPEN Top Rope Belay Lessons — September 2026", kind: "class", timezone: tz, location_kind: "venue", summary: "Open group top-rope belay lessons for climbers aged 13 and older.", schedule_kind: "recurring", schedule_note: "Nine confirmed September lesson slots are shown; later months were not inspected.", audience: ["adult"], ages: "13+", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/top-rope-lesson-open-class", link_kind: "registration"}, src.( ["https://www.guelphgrotto.com/instruction", "https://guelphgrotto.rphq.com/guelphgrotto/programs/top-rope-lesson-open-class"])), Enum.map(rope_dates, fn {d,s,e}->o.(d,nil,s,e) end))

lead_specs = [{"Sep 8–10",[~D[2026-09-08],~D[2026-09-10]],~T[18:00:00],~T[21:00:00]},{"Sep 19–20",[~D[2026-09-19],~D[2026-09-20]],~T[10:00:00],~T[13:00:00]},{"Oct 13–15",[~D[2026-10-13],~D[2026-10-15]],~T[18:00:00],~T[21:00:00]},{"Oct 17–18",[~D[2026-10-17],~D[2026-10-18]],~T[10:00:00],~T[13:00:00]},{"Nov 10–12",[~D[2026-11-10],~D[2026-11-12]],~T[18:00:00],~T[21:00:00]},{"Nov 21–22",[~D[2026-11-21],~D[2026-11-22]],~T[10:00:00],~T[13:00:00]},{"Dec 8–10",[~D[2026-12-08],~D[2026-12-10]],~T[18:00:00],~T[21:00:00]},{"Dec 19–20",[~D[2026-12-19],~D[2026-12-20]],~T[10:00:00],~T[13:00:00]}]
lead = Enum.flat_map(lead_specs, fn {n,ds,s,e}->Enum.map(ds,&o.(&1,n,s,e)) end)
put!.(Map.merge(%{id: 285, venue_id: 32, title: "OPEN Lead Belay and Climb Lessons — Fall 2026", kind: "class", timezone: tz, location_kind: "venue", summary: "Two-session lead belay and climbing lessons for experienced climbers aged 16 and older.", schedule_kind: "course", start_date: ~D[2026-09-08], end_date: ~D[2026-12-20], cohorts: Enum.map(lead_specs, fn {n,_,_,_}->n end), audience: ["adult"], ages: "16+", schedule_note: "Eight confirmed two-session cohorts are shown through December 2026; later dates were not inspected.", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/lead-belay-and-climb-lesson-open-class", link_kind: "registration"}, src.( ["https://www.guelphgrotto.com/instruction", "https://guelphgrotto.rphq.com/guelphgrotto/programs/lead-belay-and-climb-lesson-open-class"])), lead)
