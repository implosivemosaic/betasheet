alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, listing} -> IO.puts("repaired #{listing.id}: #{length(listing.occurrences)} occurrences")
    {:error, cs} -> IO.inspect(cs); raise "repair failed"
  end
end

occ = fn date, cohort, start_time, end_time -> %{date: date, cohort: cohort, start_time: start_time, end_time: end_time, timezone: tz} end
weekdays = fn first, last, weekday, skip ->
  Date.range(first, last) |> Enum.filter(fn d -> Date.day_of_week(d) == weekday and d not in skip end)
end

# The saved booking rows establish 13 named League of Ninjas cohorts, ten dates each.
lon = [
  {"LON1 Wed 16:00", 3, ~T[16:00:00], ~T[17:00:00], []},
  {"LON1 Wed 17:15", 3, ~T[17:15:00], ~T[18:15:00], []},
  {"LON1 Fri", 5, ~T[16:30:00], ~T[17:30:00], []},
  {"LON1 Sat", 6, ~T[10:45:00], ~T[11:45:00], [~D[2026-10-24]]},
  {"LON1 Mon", 1, ~T[17:15:00], ~T[18:15:00], [~D[2026-10-12]]},
  {"LON2 Wed", 3, ~T[18:30:00], ~T[19:30:00], []},
  {"LON2 Fri", 5, ~T[17:45:00], ~T[18:45:00], []},
  {"LON2 Sat", 6, ~T[12:00:00], ~T[13:00:00], [~D[2026-10-24]]},
  {"LON2 Mon 16:00", 1, ~T[16:00:00], ~T[17:00:00], [~D[2026-10-12]]},
  {"LON2 Mon 18:30", 1, ~T[18:30:00], ~T[19:30:00], [~D[2026-10-12]]},
  {"LON3 Wed", 3, ~T[19:45:00], ~T[20:45:00], []},
  {"LON3 Fri", 5, ~T[19:00:00], ~T[20:00:00], []},
  {"LON3 Mon", 1, ~T[19:45:00], ~T[20:45:00], [~D[2026-10-12]]}
]
|> Enum.flat_map(fn {cohort, weekday, start_time, end_time, skip} ->
  final_date = case weekday do
    3 -> ~D[2026-11-11]
    5 -> ~D[2026-11-13]
    6 -> ~D[2026-11-21]
    1 -> ~D[2026-11-23]
  end
  weekdays.(~D[2026-09-09], final_date, weekday, skip)
  |> Enum.map(fn date ->
    # The Nov 4 LON1 17:15 booking row is printed as 05:15–06:15 a.m.; retain it as evidence.
    if cohort == "LON1 Wed 17:15" and date == ~D[2026-11-04],
      do: occ.(date, cohort, ~T[05:15:00], ~T[06:15:00]),
      else: occ.(date, cohort, start_time, end_time)
  end)
end)
|> then(fn sessions ->
  lon_names = ["LON1 Wed 16:00", "LON1 Wed 17:15", "LON1 Fri", "LON1 Sat", "LON1 Mon", "LON2 Wed", "LON2 Fri", "LON2 Sat", "LON2 Mon 16:00", "LON2 Mon 18:30", "LON3 Wed", "LON3 Fri", "LON3 Mon"]
  put!.(%{id: 243, venue_id: 27, title: "League of Ninjas — Fall 2026 youth programmes", kind: "class", timezone: tz,
    location_kind: "venue", summary: "Progressive youth ninja training focused on balance, coordination, strength and problem-solving.",
    schedule_kind: "course", schedule_note: "Thirteen confirmed cohorts run for ten classes each; October 12 and October 24 are skipped dates. One November 4 booking row prints an anomalous 05:15 start and is retained for operator confirmation.",
    cohorts: lon_names, audience: ["youth"], ages: "Ages 6–11+", link: "https://portal.aspireclimbing.com/milton/n/ninja", link_kind: "registration",
    confidence: "check", sources: ["https://portal.aspireclimbing.com/milton/n/ninja", "https://portal.aspireclimbing.com/milton/programs/lon-10-ages-6-8", "https://portal.aspireclimbing.com/milton/programs/lon-20-ages-9-10", "https://portal.aspireclimbing.com/milton/programs/lon-30-ages-11"], checked_on: ~D[2026-09-06], published: false}, sessions)
end)

crave_dates = [~D[2026-09-14], ~D[2026-09-21], ~D[2026-09-28], ~D[2026-10-05], ~D[2026-10-19], ~D[2026-10-26], ~D[2026-11-02], ~D[2026-11-09], ~D[2026-11-16], ~D[2026-11-23]]
crave = Enum.flat_map(crave_dates, fn date -> [occ.(date, "Hikmat H — first five", ~T[21:00:00], ~T[21:45:00]), occ.(date, "Hikmat H — second five", ~T[21:00:00], ~T[21:45:00])] end)
put!.(%{id: 245, venue_id: 27, title: "Crave Ninja — Fall 2026", kind: "class", timezone: tz, location_kind: "venue",
  summary: "Adult ninja skills sessions focused on body awareness, strength, endurance and community.", schedule_kind: "course",
  schedule_note: "Two five-class cohorts meet Mondays at 21:00; October 12 is skipped.", cohorts: ["Hikmat H — first five", "Hikmat H — second five"], audience: ["adult"], ages: nil,
  link: "https://portal.aspireclimbing.com/milton/programs/league-of-ninjas-18", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/programs/league-of-ninjas-18"], checked_on: ~D[2026-09-06], published: false}, crave)

put!.(%{id: 248, venue_id: 27, title: "Aspire Ninja Showdown XI — CNL Season 7 Stage 1", kind: "competition", timezone: tz, location_kind: "venue",
  summary: "Ninja competition event in the CNL Season 7 Stage 1 series.", schedule_kind: "recurring", schedule_note: "Whole-day event bounds are Sep 19 13:00–21:00 and Sep 20 08:00–16:00. Tentative category check-in times conflict between sources and are not presented as confirmed.",
  audience: ["youth", "adult"], ages: "Multiple youth and adult categories", link: "https://portal.aspireclimbing.com/milton/programs/milton-nsd11", link_kind: "registration", confidence: "check",
  sources: ["https://www.aspireclimbing.com/milton/ninja-showdown", "https://portal.aspireclimbing.com/milton/programs/milton-nsd11"], checked_on: ~D[2026-09-06], published: false},
  [occ.(~D[2026-09-19], nil, ~T[13:00:00], ~T[21:00:00]), occ.(~D[2026-09-20], nil, ~T[08:00:00], ~T[16:00:00])])

put!.(%{id: 250, venue_id: 27, title: "Winter Day Camps — December 2026", kind: "camp", timezone: tz, location_kind: "venue",
  summary: "Youth day camps combining climbing, ninja activities and games for ages 6–12.", schedule_kind: "recurring", schedule_note: "Six individually confirmed camp dates are shown; the dates are separated by the holiday closure rather than one continuous event.",
  audience: ["youth"], ages: "6–12", link: "https://portal.aspireclimbing.com/milton/programs/winter-day-camp", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/n/camps", "https://portal.aspireclimbing.com/milton/programs/winter-day-camp"], checked_on: ~D[2026-09-06], published: false},
  Enum.map([~D[2026-12-21], ~D[2026-12-22], ~D[2026-12-23], ~D[2026-12-28], ~D[2026-12-29], ~D[2026-12-30]], &occ.(&1, nil, ~T[09:00:00], ~T[16:30:00])) )

put!.(%{id: 251, venue_id: 27, title: "March Break Camp 2027", kind: "camp", timezone: tz, location_kind: "venue",
  summary: "A full-week youth camp combining climbing, ninja activities and games for ages 6–12.", schedule_kind: "course", schedule_note: "Five confirmed camp days run March 15–19, 2027.", audience: ["youth"], ages: "6–12",
  link: "https://portal.aspireclimbing.com/milton/programs/march-camp-2", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/n/camps", "https://portal.aspireclimbing.com/milton/programs/march-camp-2"], checked_on: ~D[2026-09-06], published: false},
  Enum.map(Date.range(~D[2027-03-15], ~D[2027-03-19]), &occ.(&1, nil, ~T[09:00:00], ~T[16:30:00])) )
