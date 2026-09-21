alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn a, s -> case Import.put_listing(a, s) do {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences"); {:error, c} -> IO.inspect(c); raise "repair failed" end end
o = fn d, c, s, e -> %{date: d, cohort: c, start_time: s, end_time: e, timezone: tz} end
src = fn u -> %{sources: u, checked_on: ~D[2026-09-06], published: false, confidence: "confirmed"} end
v = %{timezone: tz, venue_id: 16, location_kind: "venue", published: false}

defs = fn id, title, summary, ages, specs, urls ->
  cohorts = Enum.map(specs, fn {n, _, _, _} -> n end)
  sessions = Enum.flat_map(specs, fn {n, dates, s, e} -> Enum.map(dates, &o.(&1, n, s, e)) end)
  put!.(Map.merge(v, %{id: id, title: title, kind: "class", summary: summary, schedule_kind: "course", cohorts: cohorts, start_date: ~D[2026-09-14], end_date: ~D[2026-10-26], audience: ["youth"], ages: ages, link: hd(urls), link_kind: "registration"}) |> Map.merge(src.(urls)), sessions)
end

defs.(31, "Blaze — September–October 2026", "Six-session youth climbing programme for developing recreational climbers.", "Youth", [
  {"Tuesday cohort", [~D[2026-09-15], ~D[2026-09-22], ~D[2026-09-29], ~D[2026-10-06], ~D[2026-10-13], ~D[2026-10-20]], ~T[17:30:00], ~T[18:30:00]},
  {"Saturday cohort", [~D[2026-09-19], ~D[2026-09-26], ~D[2026-10-03], ~D[2026-10-10], ~D[2026-10-17], ~D[2026-10-24]], ~T[10:15:00], ~T[11:15:00]}
], ["https://hubclimbing.com/mississauga/youth/youth-recreational-team/", "https://app.rockgympro.com/b/?&bo=b71ed46d79e44b0d9d773e7a454b169c"])

defs.(264, "Dragon — September–October 2026", "Six-session youth climbing programme for developing recreational climbers.", "Youth", [
  {"Thursday cohort", [~D[2026-09-17], ~D[2026-09-24], ~D[2026-10-01], ~D[2026-10-08], ~D[2026-10-15], ~D[2026-10-22]], ~T[17:00:00], ~T[18:30:00]},
  {"Saturday cohort", [~D[2026-09-19], ~D[2026-09-26], ~D[2026-10-03], ~D[2026-10-10], ~D[2026-10-17], ~D[2026-10-24]], ~T[10:30:00], ~T[12:00:00]}
], ["https://hubclimbing.com/mississauga/youth/youth-recreational-team/", "https://app.rockgympro.com/b/?bo=70bce8cbdf334a38aa54cbcf402b7860"])

defs.(265, "Wyvern — September–October 2026", "Six-session youth climbing programme for developing recreational climbers.", "Youth", [
  {"Monday cohort", [~D[2026-09-14], ~D[2026-09-21], ~D[2026-09-28], ~D[2026-10-05], ~D[2026-10-19], ~D[2026-10-26]], ~T[17:00:00], ~T[18:30:00]},
  {"Saturday cohort", [~D[2026-09-19], ~D[2026-09-26], ~D[2026-10-03], ~D[2026-10-10], ~D[2026-10-17], ~D[2026-10-24]], ~T[11:30:00], ~T[13:00:00]}
], ["https://app.rockgympro.com/b/?bo=4768a6604e554d9eaa025b5c45dff19c"])

defs.(266, "Leviathan — September–October 2026", "Six-session youth climbing programme for developing recreational climbers.", "Youth", [
  {"Monday cohort", [~D[2026-09-14], ~D[2026-09-21], ~D[2026-09-28], ~D[2026-10-05], ~D[2026-10-19], ~D[2026-10-26]], ~T[18:45:00], ~T[20:15:00]},
  {"Saturday cohort", [~D[2026-09-19], ~D[2026-09-26], ~D[2026-10-03], ~D[2026-10-10], ~D[2026-10-17], ~D[2026-10-24]], ~T[12:15:00], ~T[13:45:00]}
], ["https://app.rockgympro.com/b/?bo=203a50ed4d1a4768b10ef59065bdd84e"])

put!.(Map.merge(v, %{id: 267, title: "ARC — Advanced Recreational Program", kind: "class", summary: "Advanced youth recreational climbing programme for developing climbers.", schedule_kind: "unscheduled", recurrence: nil, weekday: nil, audience: ["youth"], ages: "Youth", link: "https://hubclimbing.com/mississauga/youth/youth-recreational-team/", link_kind: "event"}) |> Map.merge(src.( ["https://hubclimbing.com/mississauga/youth/youth-recreational-team/", "https://app.rockgympro.com/b/?bo=70bce8cbdf334a38aa54cbcf402b7860"])), :preserve)
