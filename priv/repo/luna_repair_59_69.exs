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

put!.(Map.merge(%{id: 59, venue_id: 32, title: "Arcade Night — 2026", kind: "social", timezone: tz, location_kind: "venue", summary: "Video-game-themed bouldering event with arcade-style challenges, prizes and family-friendly fun.", schedule_kind: "one_off", start_date: ~D[2026-10-23], end_date: ~D[2026-10-23], start_time: ~T[18:00:00], end_time: ~T[22:00:00], audience: ["family"], link: "https://climb.guelphgrotto.com/guelphgrotto/programs/arcade-night", link_kind: "registration"}, src.( ["https://www.guelphgrotto.com/events", "https://climb.guelphgrotto.com/guelphgrotto/programs/arcade-night", "https://www.instagram.com/guelphgrotto/p/DcUozhoCbgG/"])), [o.(~D[2026-10-23], nil, ~T[18:00:00], ~T[22:00:00])])

put!.(Map.merge(%{id: 60, venue_id: 32, title: "Member Appreciation Open House — November", kind: "social", timezone: tz, location_kind: "venue", summary: "Members' friends-and-family open house with climbing and community activities.", schedule_kind: "one_off", start_date: ~D[2026-11-20], end_date: ~D[2026-11-20], start_time: ~T[17:00:00], audience: ["family"], caveat: "The November 20, 2026 date is inferred from the current events listing; confirm the year with the gym.", link: "https://www.guelphgrotto.com/events", link_kind: "event"}, src.( ["https://www.guelphgrotto.com/events"])), [o.(~D[2026-11-20], nil, ~T[17:00:00], nil)])

put!.(Map.merge(%{id: 61, venue_id: 32, title: "Sensory-Friendly Climbing Hours", kind: "social", timezone: tz, location_kind: "venue", summary: "Saturday morning sensory-friendly climbing hours at Guelph Grotto.", schedule_kind: "recurring", recurrence: "weekly", weekday: 6, start_time: ~T[08:00:00], end_time: ~T[10:00:00], audience: ["adaptive"], link: "https://www.guelphgrotto.com/about", link_kind: "event"}, src.( ["https://www.guelphgrotto.com/", "https://www.guelphgrotto.com/about"])), :preserve)

adult_dates = [~D[2026-09-27], ~D[2026-10-04], ~D[2026-10-18], ~D[2026-10-25], ~D[2026-11-01], ~D[2026-11-08]]
put!.(Map.merge(%{id: 62, venue_id: 32, title: "Beginner Adult Technique Series", kind: "class", timezone: tz, location_kind: "venue", summary: "Six-session beginner climbing course building confidence, movement technique and belay awareness for ages 16 and older.", schedule_kind: "course", cohorts: ["September 2026 cohort"], audience: ["adult"], ages: "16+", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/beginner-adult-technique-series", link_kind: "registration"}, src.( ["https://www.guelphgrotto.com/adult-programs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/beginner-adult-technique-series", "https://guelphgrotto.rphq.com/guelphgrotto/programs/beginner-adult-technique-series-drop-in"])), Enum.map(adult_dates, &o.(&1, "September 2026 cohort", ~T[10:30:00], ~T[12:00:00])))

inter_dates = [~D[2026-09-28], ~D[2026-10-05], ~D[2026-10-19], ~D[2026-10-26], ~D[2026-11-02], ~D[2026-11-09]]
put!.(Map.merge(%{id: 63, venue_id: 32, title: "Intermediate Adult Technique Series", kind: "class", timezone: tz, location_kind: "venue", summary: "Six-session climbing technique course for adults progressing through blue and red boulder problems.", schedule_kind: "course", cohorts: ["Fall 2026 cohort"], audience: ["adult"], ages: "16+", schedule_note: "Confirmed Fall 2026 dates are shown; the October 12 holiday skip is preserved.", link: "https://guelphgrotto.rphq.com/guelphgrotto/programs/intermediate-adult-technique-series", link_kind: "registration"}, src.( ["https://www.guelphgrotto.com/adult-programs", "https://guelphgrotto.rphq.com/guelphgrotto/programs/intermediate-adult-technique-series", "https://guelphgrotto.rphq.com/guelphgrotto/programs/intermediate-adult-technique-series-drop-in"])), Enum.map(inter_dates, &o.(&1, "Fall 2026 cohort", ~T[18:30:00], ~T[20:00:00])))

put!.(Map.merge(%{id: 69, venue_id: 32, title: "Senior Youth Competitive Team Tryouts — September 2026", kind: "class", timezone: tz, location_kind: "venue", summary: "Senior youth competitive-team tryouts for experienced climbers aged 12 and older.", schedule_kind: "one_off", start_date: ~D[2026-09-12], end_date: ~D[2026-09-12], start_time: ~T[10:00:00], end_time: ~T[13:00:00], audience: ["youth"], ages: "12+", link: "https://www.instagram.com/guelphgrotto/p/DcL4pIlErMy/", link_kind: "event"}, src.( ["https://www.instagram.com/guelphgrotto/p/DcL4pIlErMy/"])), [o.(~D[2026-09-12], nil, ~T[10:00:00], ~T[13:00:00])])
