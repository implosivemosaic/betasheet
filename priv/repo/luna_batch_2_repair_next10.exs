alias ClimbOntario.Catalogue.{Import, ResearchSource}

assignment = "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
manifest = assignment |> File.read!() |> Jason.decode!() |> Map.fetch!("2")
allowed_ids =
  (Enum.map(manifest["first_ten"], & &1["id"]) ++ manifest["remaining_ids"])
  |> MapSet.new()
target_ids = [201, 202, 203, 23, 24, 234, 235, 236, 237]
unless Enum.all?(target_ids, &MapSet.member?(allowed_ids, &1)) do
  raise "target outside worker-2 manifest: #{inspect(target_ids -- MapSet.to_list(allowed_ids))}"
end

# Confirm the destination venue mapping from the read-only research handoff before writing.
research = ResearchSource.load()
by_id = Map.new(research.events, &{&1["id"], &1})
expected_gyms = %{201 => 52, 202 => 52, 203 => 52, 23 => 5, 24 => 5, 234 => 5, 235 => 5, 236 => 5, 237 => 5}
unless Enum.all?(expected_gyms, fn {id, gym_id} -> by_id[id]["gym_id"] == gym_id end) do
  raise "research gym lookup mismatch"
end

put! = fn attrs, sessions ->
  unless MapSet.member?(allowed_ids, attrs.id), do: raise "unguarded write #{attrs.id}"
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")
    {:error, cs} -> IO.inspect(cs.errors, label: "FAILED #{attrs.id}"); raise "repair failed #{attrs.id}"
  end
end

tz = "America/Toronto"

put!.(%{id: 201, venue_id: 52, title: "Parent + Baby Yoga — September 2026 six-week series", kind: "class", cohorts: [], timezone: tz, summary: "Six-week unheated yoga series for new parents and babies from roughly six weeks to crawling.", schedule_kind: "course", start_date: ~D[2026-09-16], end_date: ~D[2026-10-21], audience: ["family"], ages: "Babies roughly 6 weeks to beginning to crawl", link: "https://app.rockgympro.com/b/?bo=612589382395488d87485e98c8bd6bef", link_kind: "registration", confidence: "confirmed", caveat: "Parent healthcare-provider approval is required.", sources: ["https://arcclimbing.ca/yoga/#parent-baby-yoga-5-week-session-2", "https://app.rockgympro.com/b/?bo=612589382395488d87485e98c8bd6bef"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-16], ~D[2026-09-23], ~D[2026-09-30], ~D[2026-10-07], ~D[2026-10-14], ~D[2026-10-21]], do: %{date: d, start_time: ~T[11:00:00], end_time: ~T[12:00:00], timezone: tz}))

put!.(%{id: 202, venue_id: 52, title: "Prenatal Yoga — September 2026 six-week series", kind: "class", cohorts: [], timezone: tz, summary: "Six-week unheated prenatal yoga series with one Sunday session per week.", schedule_kind: "course", start_date: ~D[2026-09-20], end_date: ~D[2026-11-01], audience: ["adult"], ages: nil, link: "https://app.rockgympro.com/b/?bo=92224f2029f4461fb0f1cbf99421d2ec", link_kind: "registration", confidence: "confirmed", caveat: "Primary healthcare-provider approval is required; October 11 is omitted.", sources: ["https://arcclimbing.ca/yoga/#prenatal-yoga-5-week-session", "https://app.rockgympro.com/b/?bo=92224f2029f4461fb0f1cbf99421d2ec", "https://www.facebook.com/events/1875241120566541/"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-20], ~D[2026-09-27], ~D[2026-10-04], ~D[2026-10-18], ~D[2026-10-25], ~D[2026-11-01]], do: %{date: d, start_time: ~T[15:30:00], end_time: ~T[16:30:00], timezone: tz}))

put!.(%{id: 203, venue_id: 52, title: "Ongoing studio yoga, aerial and fitness classes — September 2026", kind: "class", cohorts: [], timezone: tz, summary: "Current studio yoga, aerial, Pilates and fitness offerings at ARC; dates and times vary by class.", schedule_kind: "recurring", start_date: ~D[2026-09-07], audience: [], ages: nil, link: "https://app.rockgympro.com/b/?bw=75bd9d22e6db48daaafbdc7a2ec93a0e", link_kind: "registration", confidence: "confirmed", caveat: "Times vary by offering; the displayed calendar is a partial window and does not establish an endpoint.", sources: ["https://arcclimbing.ca/yoga/", "https://app.rockgympro.com/b/?bw=75bd9d22e6db48daaafbdc7a2ec93a0e", "https://arcclimbing.ca/pricing/", "https://www.instagram.com/arcclimbing/p/DaalZvyoHKu/"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-07], start_time: ~T[11:00:00], end_time: ~T[12:00:00], timezone: tz}, %{date: ~D[2026-09-08], start_time: ~T[09:30:00], end_time: ~T[10:30:00], timezone: tz}, %{date: ~D[2026-09-08], start_time: ~T[17:00:00], end_time: ~T[18:00:00], timezone: tz}, %{date: ~D[2026-09-08], start_time: ~T[18:15:00], end_time: ~T[19:10:00], timezone: tz}, %{date: ~D[2026-09-09], start_time: ~T[18:15:00], end_time: ~T[19:15:00], timezone: tz}, %{date: ~D[2026-09-10], start_time: ~T[12:00:00], end_time: ~T[12:45:00], timezone: tz}, %{date: ~D[2026-09-10], start_time: ~T[17:00:00], end_time: ~T[17:55:00], timezone: tz}, %{date: ~D[2026-09-11], start_time: ~T[18:15:00], end_time: ~T[19:10:00], timezone: tz}, %{date: ~D[2026-09-13], start_time: ~T[09:30:00], end_time: ~T[10:45:00], timezone: tz}, %{date: ~D[2026-09-13], start_time: ~T[18:45:00], end_time: ~T[20:00:00], timezone: tz}, %{date: ~D[2026-09-20], start_time: ~T[14:15:00], end_time: ~T[15:10:00], timezone: tz}])

put!.(%{id: 23, venue_id: 5, title: "Rock Club — Fall 2026", kind: "class", cohorts: ["Monday", "Saturday", "Sunday"], timezone: tz, summary: "Youth climbing lessons and games for ages 7–10 across Monday, Saturday and Sunday cohorts.", schedule_kind: "course", start_date: ~D[2026-09-12], end_date: ~D[2026-12-14], audience: ["youth"], ages: "Ages 7–10", link: "https://app.rockgympro.com/b/?bo=128a64414f364ad78c045e192075f1b3", link_kind: "registration", confidence: "confirmed", caveat: "Holiday dates are omitted from each cohort calendar.", sources: ["https://app.rockgympro.com/b/?bo=128a64414f364ad78c045e192075f1b3", "https://www.joerockheads.com/schoolofrock"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-14],~D[2026-09-21],~D[2026-09-28],~D[2026-10-05],~D[2026-10-19],~D[2026-10-26],~D[2026-11-02],~D[2026-11-09],~D[2026-11-16],~D[2026-11-23],~D[2026-11-30],~D[2026-12-07],~D[2026-12-14]], do: %{date: d, cohort: "Monday", start_time: ~T[16:30:00], end_time: ~T[18:00:00], timezone: tz}) ++
  (for d <- [~D[2026-09-12],~D[2026-09-19],~D[2026-09-26],~D[2026-10-03],~D[2026-10-17],~D[2026-10-24],~D[2026-10-31],~D[2026-11-07],~D[2026-11-14],~D[2026-11-21],~D[2026-11-28],~D[2026-12-05],~D[2026-12-12]], do: %{date: d, cohort: "Saturday", start_time: ~T[09:00:00], end_time: ~T[10:30:00], timezone: tz}) ++
  (for d <- [~D[2026-09-13],~D[2026-09-20],~D[2026-09-27],~D[2026-10-04],~D[2026-10-18],~D[2026-10-25],~D[2026-11-01],~D[2026-11-08],~D[2026-11-15],~D[2026-11-22],~D[2026-11-29],~D[2026-12-06],~D[2026-12-13]], do: %{date: d, cohort: "Sunday", start_time: ~T[09:30:00], end_time: ~T[11:00:00], timezone: tz}) )

put!.(%{id: 24, venue_id: 5, title: "Rec Team — Fall 2026", kind: "class", cohorts: ["Wednesday", "Saturday", "Sunday"], timezone: tz, summary: "Youth climbing and belaying lessons for ages 10–16 across three fall cohorts.", schedule_kind: "course", start_date: ~D[2026-09-09], end_date: ~D[2026-12-16], audience: ["youth"], ages: "Ages 10–16", link: "https://app.rockgympro.com/b/?bo=b55e8e60654f497993b76a7e66ce3929", link_kind: "registration", confidence: "confirmed", caveat: "Wednesday sessions are currently full; holiday dates are omitted from weekend calendars.", sources: ["https://app.rockgympro.com/b/?bo=b55e8e60654f497993b76a7e66ce3929", "https://www.joerockheads.com/schoolofrock"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-09],~D[2026-09-16],~D[2026-09-23],~D[2026-09-30],~D[2026-10-07],~D[2026-10-14],~D[2026-10-21],~D[2026-10-28],~D[2026-11-04],~D[2026-11-11],~D[2026-11-18],~D[2026-11-25],~D[2026-12-02],~D[2026-12-09],~D[2026-12-16]], do: %{date: d, cohort: "Wednesday", start_time: ~T[16:30:00], end_time: ~T[18:00:00], timezone: tz}) ++
  (for d <- [~D[2026-09-12],~D[2026-09-19],~D[2026-09-26],~D[2026-10-03],~D[2026-10-17],~D[2026-10-24],~D[2026-10-31],~D[2026-11-07],~D[2026-11-14],~D[2026-11-21],~D[2026-11-28],~D[2026-12-05],~D[2026-12-12]], do: %{date: d, cohort: "Saturday", start_time: ~T[11:00:00], end_time: ~T[12:30:00], timezone: tz}) ++
  (for d <- [~D[2026-09-13],~D[2026-09-20],~D[2026-09-27],~D[2026-10-04],~D[2026-10-18],~D[2026-10-25],~D[2026-11-01],~D[2026-11-08],~D[2026-11-15],~D[2026-11-22],~D[2026-11-29],~D[2026-12-06],~D[2026-12-13]], do: %{date: d, cohort: "Sunday", start_time: ~T[11:30:00], end_time: ~T[13:00:00], timezone: tz}))

put!.(%{id: 234, venue_id: 5, title: "Dev Team — Fall 2026", kind: "class", cohorts: [], timezone: tz, summary: "Invite-only development climbing team for experienced youth ages 10–16.", schedule_kind: "recurring", start_time: ~T[17:00:00], end_time: ~T[19:00:00], audience: ["youth"], ages: "Ages 10–16", link: "https://www.joerockheads.com/schoolofrock", link_kind: "event", confidence: "confirmed", caveat: "Invite-only; exact cohort dates and class count are not published.", sources: ["https://www.joerockheads.com/schoolofrock", "https://www.instagram.com/joerockheads/p/DcbcFj1kUPI/"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 235, venue_id: 5, title: "School of Rock — Winter and Spring 2027 terms forthcoming", kind: "class", cohorts: [], timezone: tz, summary: "Winter and spring 2027 School of Rock terms are planned, with exact dates and cohorts forthcoming.", schedule_kind: "unscheduled", audience: ["youth"], ages: nil, link: "https://www.joerockheads.com/schoolofrock", link_kind: "event", confidence: "tentative", caveat: "Exact dates, cohorts, prices and enrollment openings are not published.", sources: ["https://www.joerockheads.com/schoolofrock"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 236, venue_id: 5, title: "PA Day Camp — 2026–2027", kind: "camp", cohorts: [], timezone: tz, summary: "Full-day climbing and games camp for children ages 6–12 on four announced PA days.", schedule_kind: "course", start_date: ~D[2026-11-20], end_date: ~D[2027-06-04], audience: ["youth", "family"], ages: "Ages 6–12", link: "https://app.rockgympro.com/b/?bo=89f5093ddf2540b6b5ddb390f0c3199d", link_kind: "registration", confidence: "confirmed", caveat: "June 4 is not yet bookable; older 2024–25 copy was not used.", sources: ["https://www.joerockheads.com/camps", "https://app.rockgympro.com/b/?bo=89f5093ddf2540b6b5ddb390f0c3199d", "https://www.joerockheads.com/paday"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-11-20], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: tz}, %{date: ~D[2027-01-15], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: tz}, %{date: ~D[2027-02-12], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: tz}, %{date: ~D[2027-06-04], start_time: ~T[09:00:00], end_time: ~T[16:00:00], timezone: tz}])

put!.(%{id: 237, venue_id: 5, title: "Summer Camp 2027 — registration announcement", kind: "camp", cohorts: [], timezone: tz, summary: "Summer 2027 camp registration is announced for January; dates are forthcoming.", schedule_kind: "unscheduled", audience: ["youth", "family"], ages: nil, link: "https://www.joerockheads.com/camps", link_kind: "event", confidence: "tentative", caveat: "Registration is announced for January; camp dates, times, eligibility and price are unknown.", sources: ["https://www.joerockheads.com/camps", "https://app.rockgympro.com/b/?bo=c8358c6539d34d48bb65b777ce8299b0"], checked_on: ~D[2026-09-06], published: false}, [])

IO.puts("repair checkpoint complete: #{length(target_ids)} records")
