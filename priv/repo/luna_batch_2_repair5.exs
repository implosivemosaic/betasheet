alias ClimbOntario.Catalogue.Import

put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")
    {:error, cs} -> IO.inspect(cs.errors, label: "FAILED #{attrs.id}"); raise "repair failed #{attrs.id}"
  end
end

# Explicit, reviewed records only. Source evidence is listed in the companion report.
put!.(%{id: 187, venue_id: 52, title: "March Break Camp 2027", kind: "camp", cohorts: [], timezone: "America/Toronto",
  summary: "March Break climbing camp for ages 6–13 with games, yoga activities and crafts.", schedule_kind: "course",
  start_date: ~D[2027-03-15], end_date: ~D[2027-03-19], start_time: ~T[09:00:00], end_time: ~T[16:00:00], audience: ["youth", "family"], ages: "Ages 6–13",
  link: "https://arcclimbing.ca/kids-at-arc/#march-break-camp", link_kind: "event", confidence: "confirmed", caveat: nil,
  sources: ["https://app.rockgympro.com/b/?bo=0f8dc9ecc10543229edf09f8433f39c6", "https://arcclimbing.ca/kids-at-arc/#march-break-camp"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2027-03-15], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"},
   %{date: ~D[2027-03-16], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"},
   %{date: ~D[2027-03-17], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"},
   %{date: ~D[2027-03-18], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"},
   %{date: ~D[2027-03-19], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: "America/Toronto"}])

put!.(%{id: 188, venue_id: 52, title: "Holiday Camp — dates coming soon", kind: "camp", cohorts: [], timezone: "America/Toronto",
  summary: "Holiday break climbing camp with games, yoga activities and crafts for children.", schedule_kind: "unscheduled",
  audience: ["youth", "family"], ages: "Ages 6–13; booking page says ages 6–12", link: "https://arcclimbing.ca/kids-at-arc/#holidaycamp", link_kind: "event",
  confidence: "tentative", caveat: nil, sources: ["https://app.rockgympro.com/b/?bo=25dd415dcdb14ec8b83adad4b2179e94", "https://arcclimbing.ca/kids-at-arc/#holidaycamp"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 189, venue_id: 52, title: "ARC Summer Camps 2027 — registration coming soon", kind: "camp", cohorts: [], timezone: "America/Toronto",
  summary: "ARC summer camps announced for children in 2027.", schedule_kind: "unscheduled", audience: ["youth", "family"], ages: nil,
  link: "https://arcclimbing.ca/kids-at-arc/#summer-camps", link_kind: "event", confidence: "tentative", caveat: nil,
  sources: ["https://arcclimbing.ca/"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 194, venue_id: 52, title: "Aerial Kids Flips+Tricks — October 2026", kind: "class", cohorts: [], timezone: "America/Toronto",
  summary: "Three-class aerial series for ages 8–12 building movement, awareness and strength.", schedule_kind: "course",
  start_date: ~D[2026-10-04], end_date: ~D[2026-10-25], start_time: ~T[13:15:00], end_time: ~T[14:00:00], audience: ["youth"], ages: "Ages 8–12; requires the Aerial Kids Intro series",
  link: "https://app.rockgympro.com/b/?bo=2da15512f96d4c03a041bb0c1503b13b", link_kind: "registration", confidence: "confirmed", caveat: nil,
  sources: ["https://app.rockgympro.com/b/?bo=2da15512f96d4c03a041bb0c1503b13b", "https://arcclimbing.ca/kids-at-arc/#aerial-kids-ages-8-12-2"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-10-04], start_time: ~T[13:15:00], end_time: ~T[14:00:00], timezone: "America/Toronto"},
   %{date: ~D[2026-10-18], start_time: ~T[13:15:00], end_time: ~T[14:00:00], timezone: "America/Toronto"},
   %{date: ~D[2026-10-25], start_time: ~T[13:15:00], end_time: ~T[14:00:00], timezone: "America/Toronto"}])

put!.(%{id: 198, venue_id: 52, title: "No Partner? No Problem!", kind: "social", cohorts: [], timezone: "America/Toronto",
  summary: "Weekly staff-assisted social climbing for solo climbers looking to meet partners.", schedule_kind: "recurring",
  start_time: ~T[18:30:00], end_time: ~T[20:30:00], recurrence: "weekly", weekday: 2, audience: [], ages: nil,
  link: "https://arcclimbing.ca/registration_forms/no-partner-no-problem/", link_kind: "registration", confidence: "confirmed", caveat: nil,
  sources: ["https://app.rockgympro.com/b/?bo=cf40d3ee84a441cc965e3d14b0fb8ee8", "https://arcclimbing.ca/climbing/"], checked_on: ~D[2026-09-06], published: false}, [])

IO.puts("repair checkpoint complete: 5 records")
