alias ClimbOntario.Catalogue.Import

put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, listing} ->
      IO.puts("imported #{listing.id}: #{length(listing.occurrences)} occurrences, published=#{listing.published}")
      listing
    {:error, changeset} ->
      IO.inspect(changeset.errors, label: "IMPORT FAILED #{attrs[:id]}")
      raise "import failed for #{attrs[:id]}"
  end
end

# Worker 2: exactly the assigned first ten. All remain drafts for coordinator review.
put!.(%{id: 301, venue_id: 17, title: "OCF Boulder U11/ U13/ U15 — 2027-01-30", kind: "competition", ocf: true,
  cohorts: [], timezone: "America/Toronto", summary: "Ontario Climbing Federation bouldering competition for U11, U13 and U15 athletes.",
  schedule_kind: "multi_day", start_date: ~D[2027-01-30], end_date: ~D[2027-01-31], audience: ["youth"], ages: "U11, U13 and U15",
  link: "https://www.climbontario.ca/events/ocf-boulder-u11-u13-u15-1", link_kind: "event", confidence: "tentative", caveat: nil,
  sources: ["https://www.climbontario.ca/events/ocf-boulder-u11-u13-u15-1", "https://www.climbontario.ca/news/ocf-2026-27-competition-season"],
  checked_on: ~D[2026-09-07], published: false},
  [%{date: ~D[2027-01-30], timezone: "America/Toronto"}, %{date: ~D[2027-01-31], timezone: "America/Toronto"}])

put!.(%{id: 185, venue_id: 52, title: "ARC Flash 2026", kind: "competition", ocf: false, cohorts: [], timezone: "America/Toronto",
  summary: "Annual ARC bouldering competition with Junior, Fun and Experienced divisions and a post-event social.", schedule_kind: "one_off",
  start_date: ~D[2026-09-25], end_date: ~D[2026-09-25], start_time: ~T[18:00:00], end_time: ~T[21:00:00], audience: ["youth", "adult"], ages: "Ages 6+",
  link: "https://app.rockgympro.com/b/?bo=b9f3e634218e4ec7b98866652a46748e", link_kind: "registration", confidence: "confirmed", caveat: nil,
  sources: ["https://arcclimbing.ca/events/arc-flash/", "https://app.rockgympro.com/b/?bo=b9f3e634218e4ec7b98866652a46748e"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-25], start_time: ~T[18:00:00], end_time: ~T[21:00:00], timezone: "America/Toronto"}])

put!.(%{id: 186, venue_id: 52, title: "PA Day Camp — 2026–2027", kind: "camp", cohorts: [], timezone: "America/Toronto",
  summary: "PA Day camp for ages 6–14 with staff-belayed climbing, games, crafts and yoga.", schedule_kind: "recurring", audience: ["youth", "family"], ages: "Ages 6–14",
  link: "https://app.rockgympro.com/b/?bo=d180fbccef08491a814bc579129f7e80", link_kind: "registration", confidence: "confirmed", caveat: nil,
  sources: ["https://arcclimbing.ca/kids-at-arc/#padaycamp", "https://app.rockgympro.com/b/?bo=d180fbccef08491a814bc579129f7e80"], checked_on: ~D[2026-09-06], published: false},
  [~D[2026-10-26], ~D[2026-11-20], ~D[2027-02-01], ~D[2027-04-23], ~D[2027-06-11]])

put!.(%{id: 190, venue_id: 52, title: "Youth Climbing Team Tryouts — September 2026", kind: "class", cohorts: [], timezone: "America/Toronto",
  summary: "Tryout for ARC's invite-only youth climbing team for experienced young climbers.", schedule_kind: "one_off", start_date: ~D[2026-09-13], end_date: ~D[2026-09-13], start_time: ~T[16:00:00], end_time: ~T[18:00:00],
  audience: ["youth"], ages: "Typically ages 11–17; no formal minimum stated", link: "https://app.rockgympro.com/b/?bo=b27683c898bd4c1d9aab55dab5451e6f", link_kind: "registration", confidence: "confirmed", caveat: nil,
  sources: ["https://arcclimbing.ca/kids-at-arc/#youth-climbing-team-2", "https://app.rockgympro.com/b/?bo=b27683c898bd4c1d9aab55dab5451e6f"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-13], start_time: ~T[16:00:00], end_time: ~T[18:00:00], timezone: "America/Toronto"}])

put!.(%{id: 191, venue_id: 52, title: "Youth Climbing Team — Fall/Winter terms", kind: "class", cohorts: [], timezone: "America/Toronto",
  summary: "Invite-only youth climbing team developing technique, fitness, belaying and lead skills with rotating coaches.", schedule_kind: "unscheduled",
  audience: ["youth"], ages: "Typically ages 11–17; no formal minimum stated", link: "https://arcclimbing.ca/kids-at-arc/#youth-climbing-team", link_kind: "event", confidence: "tentative", caveat: nil,
  sources: ["https://arcclimbing.ca/kids-at-arc/#youth-climbing-team", "https://app.rockgympro.com/b/?bo=ddd6403056ae4948bfabf79837bf7929"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 192, venue_id: 52, title: "Youth Recreational Climbing — Fall 2026", kind: "class", cohorts: ["Saturday morning", "Tuesday 4:30 pm", "Tuesday 5:45 pm"], timezone: "America/Toronto",
  summary: "Seven-week youth climbing for ages 6–13 with fundamentals, technique, games and creative play.", schedule_kind: "course", start_date: ~D[2026-09-12], end_date: ~D[2026-10-31], audience: ["youth"], ages: "Ages 6–13",
  link: "https://app.rockgympro.com/b/?bw=da1a74e793f94ae888ee436bfbfd52ec&bo=8ca7f9c2ebf2493f903d2d7ef05640ce", link_kind: "registration", confidence: "confirmed", caveat: "No Saturday class on October 10.",
  sources: ["https://arcclimbing.ca/kids-at-arc/#youth-rec", "https://app.rockgympro.com/b/?bw=da1a74e793f94ae888ee436bfbfd52ec&bo=8ca7f9c2ebf2493f903d2d7ef05640ce"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-12], ~D[2026-09-19], ~D[2026-09-26], ~D[2026-10-03], ~D[2026-10-17], ~D[2026-10-24], ~D[2026-10-31]], do: %{date: d, cohort: "Saturday morning", start_time: ~T[09:00:00], end_time: ~T[10:00:00], timezone: "America/Toronto"}) ++
  (for d <- [~D[2026-09-15], ~D[2026-09-22], ~D[2026-09-29], ~D[2026-10-06], ~D[2026-10-13], ~D[2026-10-20], ~D[2026-10-27]], do: %{date: d, cohort: "Tuesday 4:30 pm", start_time: ~T[16:30:00], end_time: ~T[17:30:00], timezone: "America/Toronto"}) ++
  (for d <- [~D[2026-09-15], ~D[2026-09-22], ~D[2026-09-29], ~D[2026-10-06], ~D[2026-10-13], ~D[2026-10-20], ~D[2026-10-27]], do: %{date: d, cohort: "Tuesday 5:45 pm", start_time: ~T[17:45:00], end_time: ~T[18:45:00], timezone: "America/Toronto"}))

put!.(%{id: 193, venue_id: 52, title: "Aerial Kids Intro — October 2026", kind: "class", cohorts: [], timezone: "America/Toronto",
  summary: "Three-class aerial yoga basics series for ages 8–12, building awareness, creativity and strength.", schedule_kind: "course", start_date: ~D[2026-10-04], end_date: ~D[2026-10-25], start_time: ~T[12:15:00], end_time: ~T[13:00:00], audience: ["youth"], ages: "Ages 8–12",
  link: "https://app.rockgympro.com/b/?bo=fae0c72f8d9a436199cc33639fc6aeaf", link_kind: "registration", confidence: "confirmed", caveat: "No class on October 11.", sources: ["https://arcclimbing.ca/kids-at-arc/#aerial-kids-ages-8-12", "https://app.rockgympro.com/b/?bo=fae0c72f8d9a436199cc33639fc6aeaf"], checked_on: ~D[2026-09-06], published: false},
  [~D[2026-10-04], ~D[2026-10-18], ~D[2026-10-25]])

put!.(%{id: 195, venue_id: 52, title: "Learn to Belay", kind: "class", cohorts: [], timezone: "America/Toronto",
  summary: "Belay fundamentals for ages 14+ covering harness use, tie-in and partner belaying, with time to practise climbing.", schedule_kind: "recurring", audience: ["adult", "youth"], ages: "Ages 14+",
  link: "https://app.rockgympro.com/b/?bo=7044ad45c3874911bf2bf5beaa024b96", link_kind: "registration", confidence: "confirmed", caveat: nil, sources: ["https://arcclimbing.ca/climbing/#belaycourse", "https://app.rockgympro.com/b/?bo=7044ad45c3874911bf2bf5beaa024b96"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-06], start_time: ~T[14:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"}, %{date: ~D[2026-09-10], start_time: ~T[18:00:00], end_time: ~T[20:00:00], timezone: "America/Toronto"}, %{date: ~D[2026-09-17], start_time: ~T[18:00:00], end_time: ~T[20:00:00], timezone: "America/Toronto"}, %{date: ~D[2026-09-20], start_time: ~T[14:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"}, %{date: ~D[2026-09-24], start_time: ~T[18:00:00], end_time: ~T[20:00:00], timezone: "America/Toronto"}])

put!.(%{id: 196, venue_id: 52, title: "Learn to Lead Climb", kind: "class", cohorts: [], timezone: "America/Toronto", summary: "Two-part lead climbing course for advanced climbers with prior belaying experience and manager approval.", schedule_kind: "unscheduled", audience: ["adult", "youth"], ages: "Ages 14+",
  link: "https://arcclimbing.ca/climbing/#learn-lead-climb", link_kind: "event", confidence: "tentative", caveat: nil, sources: ["https://arcclimbing.ca/climbing/#learn-lead-climb", "https://app.rockgympro.com/b/?bo=5f8e9b7337e643a1b9852a9a503d446f"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 197, venue_id: 52, title: "Pop-Up Outdoor Climb — Timberwolf", kind: "class", cohorts: [], timezone: "America/Toronto", summary: "Staff-supported outdoor climb at Timberwolf crag in New Sudbury for belay-certified ARC climbers.", schedule_kind: "one_off", start_date: ~D[2026-09-10], end_date: ~D[2026-09-10], start_time: ~T[18:00:00], end_time: ~T[20:30:00], audience: ["adult", "youth"], ages: "Ages 14+; ages 10–13 with a parent or guardian",
  location_kind: "offsite", offsite_name: "Timberwolf crag", offsite_city: "New Sudbury", link: "https://app.rockgympro.com/b/?bo=fa94e0c3d3cb42808a8747c2919a2e9d", link_kind: "registration", confidence: "confirmed", caveat: "Meeting point is described as the end of Barrydowne past Maley Drive; a precise address is not provided.", sources: ["https://arcclimbing.ca/climbing/#pop-outdoor-climbs", "https://app.rockgympro.com/b/?bo=fa94e0c3d3cb42808a8747c2919a2e9d"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-10], start_time: ~T[18:00:00], end_time: ~T[20:30:00], timezone: "America/Toronto", location_kind: "offsite", offsite_name: "Timberwolf crag", offsite_city: "New Sudbury"}])

IO.puts("worker 2 batch complete: 10 assigned drafts")
