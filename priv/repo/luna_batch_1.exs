alias ClimbOntario.Catalogue.Import
alias ClimbOntario.Catalogue.{Listing, Occurrence}
alias ClimbOntario.Repo
import Ecto.Query

venue = fn source_id -> Repo.get_by!(ClimbOntario.Catalogue.Venue, source_gym_id: source_id).id end
base = fn attrs ->
  Map.merge(%{published: false, location_kind: "venue", audience: [], cohorts: [], sources: []}, attrs)
end
put! = fn attrs, sessions ->
  {:ok, listing} = Import.put_listing(base.(attrs), sessions)
  IO.puts("imported #{listing.id} #{length(listing.occurrences)} occurrences")
end

# OCF evidence is the official event page and season article; date/time is not confirmed.
put!.(%{id: 311, venue_id: venue.(33), title: "OCF Lead U17/ U19/ U21 — 2026-11-28",
  kind: "competition", ocf: true, cohorts: ["U17", "U19", "U21"], timezone: "America/Toronto",
  summary: "OCF lead competition for U17, U19 and U21 categories.", schedule_kind: "one_off",
  start_date: ~D[2026-11-28], end_date: ~D[2026-11-28], audience: ["youth"], ages: "U17, U19, U21",
  link: "https://www.climbontario.ca/events/ocf-lead-u17-u19-u21", link_kind: "event", confidence: "confirmed",
  caveat: "Athlete schedule and registration details are not yet published.",
  sources: ["https://www.climbontario.ca/events/ocf-lead-u17-u19-u21", "https://www.climbontario.ca/news/ocf-2026-27-competition-season"], checked_on: ~D[2026-09-07]},
  [%{date: ~D[2026-11-28], cohort: "U17", start_time: nil, end_time: nil, timezone: nil},
   %{date: ~D[2026-11-28], cohort: "U19", start_time: nil, end_time: nil, timezone: nil},
   %{date: ~D[2026-11-28], cohort: "U21", start_time: nil, end_time: nil, timezone: nil}])

put!.(%{id: 64, venue_id: venue.(33), title: "Junction Journey Ep.10: Ice Cream", kind: "social",
  summary: "District Ice Cream visits Junction Climbing Centre for an hour of ice cream.", schedule_kind: "one_off",
  start_date: ~D[2026-09-07], end_date: ~D[2026-09-07], start_time: ~T[13:00:00], end_time: ~T[14:00:00], timezone: "America/Toronto",
  audience: ["family"], link: "https://www.junctionclimbing.com/event-database/ep-10-ice-cream", link_kind: "event", confidence: "confirmed",
  sources: ["https://www.junctionclimbing.com/event-database/ep-10-ice-cream"], checked_on: ~D[2026-09-06]},
  [%{date: ~D[2026-09-07]}])

put!.(%{id: 65, venue_id: venue.(33), title: "Junction Journey Ep.11: Tote Bag Craft", kind: "social",
  summary: "A tote-bag craft workshop for climbing or grocery bags, with totes provided.", schedule_kind: "one_off",
  start_date: ~D[2026-09-15], end_date: ~D[2026-09-15], start_time: ~T[18:00:00], end_time: ~T[21:00:00], timezone: "America/Toronto",
  link: "https://www.junctionclimbing.com/event-database/ep-11-tote-bag-craft", link_kind: "event", confidence: "confirmed",
  sources: ["https://www.junctionclimbing.com/event-database/ep-11-tote-bag-craft", "https://app.rockgympro.com/b/?bo=0d325455c7c84e7ca910d71662392f0f"], checked_on: ~D[2026-09-06]},
  [%{date: ~D[2026-09-15]}])

put!.(%{id: 67, venue_id: venue.(33), title: "Adult Development Program — Fall 2026", kind: "class",
  summary: "Coached climbing and technique development for adults 18 and older.", schedule_kind: "course",
  start_date: ~D[2026-09-23], end_date: ~D[2026-12-02], start_time: ~T[19:30:00], end_time: ~T[20:30:00], timezone: "America/Toronto",
  audience: ["adult"], ages: "Ages 18+", recurrence: "weekly", weekday: 3,
  link: "https://www.junctionclimbing.com/adult-programming", link_kind: "registration", confidence: "confirmed",
  caveat: "Belay certification is required before the first class.",
  sources: ["https://www.junctionclimbing.com/adult-programming", "https://app.rockgympro.com/b/?bo=88ee3cc3b602467092a8d5c18e8c1266"], checked_on: ~D[2026-09-06]},
  Enum.map(~w[2026-09-23 2026-09-30 2026-10-07 2026-10-21 2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02], &%{date: Date.from_iso8601!(&1)}))

junior_dates = fn weekday ->
  case weekday do
    :friday -> ~w[2026-09-18 2026-09-25 2026-10-02 2026-10-16 2026-10-23 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27]
    :sunday -> ~w[2026-09-20 2026-09-27 2026-10-04 2026-10-18 2026-10-25 2026-11-01 2026-11-08 2026-11-15 2026-11-22 2026-11-29]
    :monday -> ~w[2026-09-21 2026-09-28 2026-10-05 2026-10-19 2026-10-26 2026-11-02 2026-11-09 2026-11-16 2026-11-23 2026-11-30]
    :tue -> ~w[2026-09-22 2026-09-29 2026-10-06 2026-10-20 2026-10-27 2026-11-03 2026-11-10 2026-11-17 2026-11-24 2026-12-01]
    :wed -> ~w[2026-09-23 2026-09-30 2026-10-07 2026-10-21 2026-10-28 2026-11-04 2026-11-11 2026-11-18 2026-11-25 2026-12-02]
    :thu -> ~w[2026-09-24 2026-10-01 2026-10-08 2026-10-22 2026-10-29 2026-11-05 2026-11-12 2026-11-19 2026-11-26 2026-12-03]
  end
end
junior_cohorts = [
  {"Friday 17:00", :friday, ~T[17:00:00], ~T[18:00:00]}, {"Sunday 09:00", :sunday, ~T[09:00:00], ~T[10:00:00]},
  {"Monday 18:15", :monday, ~T[18:15:00], ~T[19:15:00]}, {"Tuesday 17:00", :tue, ~T[17:00:00], ~T[18:00:00]},
  {"Tuesday 20:00", :tue, ~T[20:00:00], ~T[21:00:00]}, {"Wednesday 19:45", :wed, ~T[19:45:00], ~T[20:45:00]},
  {"Thursday 17:00", :thu, ~T[17:00:00], ~T[18:00:00]}
]
put!.(%{id: 68, venue_id: venue.(33), title: "Junior Crushers — Fall 2026", kind: "class", cohorts: Enum.map(junior_cohorts, &elem(&1, 0)),
  summary: "Recreational climbing for children born 2016–2021, with equipment provided during sessions.", schedule_kind: "course",
  start_date: ~D[2026-09-18], end_date: ~D[2026-12-03], timezone: "America/Toronto", audience: ["youth"], ages: "Born 2016–2021",
  link: "https://www.junctionclimbing.com/youth-programs", link_kind: "registration", confidence: "confirmed",
  sources: ["https://www.junctionclimbing.com/youth-programs", "https://app.rockgympro.com/b/?bo=b8cd2a7bc51d4e3ca29a6fbc1fd2198a"], checked_on: ~D[2026-09-06]},
  Enum.flat_map(junior_cohorts, fn {cohort, day, start, finish} -> Enum.map(junior_dates.(day), &%{date: Date.from_iso8601!(&1), cohort: cohort, start_time: start, end_time: finish}) end))

put!.(%{id: 20, venue_id: venue.(27), title: "League of Ninjas Cup — remaining 2026 dates", kind: "competition", ocf: false,
  summary: "Monthly recreational ninja competition with one course, two runs and combined points.", schedule_kind: "course",
  start_date: ~D[2026-09-26], end_date: ~D[2026-12-21], timezone: "America/Toronto", audience: ["family"],
  link: "https://portal.aspireclimbing.com/milton/programs/league-of-ninjas-cup", link_kind: "registration", confidence: "check",
  sources: ["https://www.aspireclimbing.com/milton/events", "https://portal.aspireclimbing.com/milton/programs/league-of-ninjas-cup"], checked_on: ~D[2026-09-06]},
  [%{date: ~D[2026-09-26]}, %{date: ~D[2026-12-21]}])

put!.(%{id: 244, venue_id: venue.(27), title: "Crave Climbing — Fall 2026", kind: "class",
  summary: "Adult bouldering technique classes covering skills, strength and endurance.", schedule_kind: "course",
  start_date: ~D[2026-09-11], end_date: ~D[2026-11-13], start_time: ~T[21:00:00], end_time: ~T[21:45:00], timezone: "America/Toronto",
  audience: ["adult"], ages: "Adults", recurrence: "weekly", weekday: 5,
  link: "https://portal.aspireclimbing.com/milton/programs/crave-climbing", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/programs/crave-climbing"], checked_on: ~D[2026-09-06]},
  Enum.map(~w[2026-09-11 2026-09-18 2026-09-25 2026-10-02 2026-10-09 2026-10-16 2026-10-23 2026-10-30 2026-11-06 2026-11-13], &%{date: Date.from_iso8601!(&1)}))

put!.(%{id: 246, venue_id: venue.(27), title: "Crave Fitness — Fall 2026", kind: "class",
  summary: "Adult fitness classes building training knowledge, strength and endurance.", schedule_kind: "course",
  start_date: ~D[2026-09-09], end_date: ~D[2026-11-11], start_time: ~T[21:00:00], end_time: ~T[21:45:00], timezone: "America/Toronto",
  audience: ["adult"], ages: "Adults", recurrence: "weekly", weekday: 3,
  link: "https://portal.aspireclimbing.com/milton/programs/hit-bootcamp-adult-2", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/programs/hit-bootcamp-adult-2"], checked_on: ~D[2026-09-06]},
  Enum.map(~w[2026-09-09 2026-09-16 2026-09-23 2026-09-30 2026-10-07 2026-10-14 2026-10-21 2026-10-28 2026-11-04 2026-11-11], &%{date: Date.from_iso8601!(&1)}))

put!.(%{id: 247, venue_id: venue.(27), title: "Member's Perk Night — September 2026", kind: "social",
  summary: "A member community evening with climbing, ninja and multisport games.", schedule_kind: "one_off",
  start_date: ~D[2026-09-25], end_date: ~D[2026-09-25], start_time: ~T[18:00:00], end_time: ~T[23:00:00], timezone: "America/Toronto",
  link: "https://portal.aspireclimbing.com/milton/programs/members-perk-night-asp", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/programs/members-perk-night-asp"], checked_on: ~D[2026-09-06]}, [%{date: ~D[2026-09-25]}])

put!.(%{id: 249, venue_id: venue.(27), title: "Halton PA Day Camps — 2026–2027", kind: "camp", cohorts: ["2026-10-09", "2026-11-27", "2027-02-05"],
  summary: "Full-day PA day camp for ages 6–12 with climbing, ninja and games.", schedule_kind: "course",
  start_date: ~D[2026-10-09], end_date: ~D[2027-02-05], start_time: ~T[09:00:00], end_time: ~T[16:30:00], timezone: "America/Toronto",
  audience: ["youth"], ages: "Ages 6–12", link: "https://portal.aspireclimbing.com/milton/programs/pa-day-camp", link_kind: "registration", confidence: "confirmed",
  sources: ["https://portal.aspireclimbing.com/milton/n/camps", "https://portal.aspireclimbing.com/milton/programs/pa-day-camp"], checked_on: ~D[2026-09-06]},
  Enum.map(~w[2026-10-09 2026-11-27 2027-02-05], fn d -> %{date: Date.from_iso8601!(d), cohort: d} end))

ids = [311, 64, 65, 67, 68, 20, 244, 246, 247, 249]
rows = Repo.all(from l in Listing, where: l.id in ^ids, preload: [occurrences: :venue])
IO.puts("verified listings=#{length(rows)} published=#{Enum.count(rows, & &1.published)} occurrences=#{Enum.sum(Enum.map(rows, &length(&1.occurrences)))}")
for id <- ids do
  result = Repo.transaction(fn ->
    {:ok, _} = Import.publish(id)
    Repo.rollback(:deliberate_validation_rollback)
  end)
  unless result == {:error, :deliberate_validation_rollback}, do: raise "publish rollback failed for #{id}"
end
IO.puts("publish validation attempted and rolled back")
rows = Repo.all(from l in Listing, where: l.id in ^ids, preload: [occurrences: :venue])
IO.puts("final published=#{Enum.count(rows, & &1.published)}")
