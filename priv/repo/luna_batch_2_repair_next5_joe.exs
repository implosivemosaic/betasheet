alias ClimbOntario.Catalogue.{Import, ResearchSource}

manifest = "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json" |> File.read!() |> Jason.decode!() |> Map.fetch!("2")
allowed_ids = (Enum.map(manifest["first_ten"], & &1["id"]) ++ manifest["remaining_ids"]) |> MapSet.new()
target_ids = [238, 239, 240, 241, 242]
unless Enum.all?(target_ids, &MapSet.member?(allowed_ids, &1)), do: raise "target outside worker-2 manifest"
research = ResearchSource.load()
by_id = Map.new(research.events, &{&1["id"], &1})
unless Enum.all?(target_ids, &(by_id[&1]["gym_id"] == 5)), do: raise "research gym lookup mismatch"

put! = fn attrs, sessions ->
  unless MapSet.member?(allowed_ids, attrs.id), do: raise "unguarded write #{attrs.id}"
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")
    {:error, cs} -> IO.inspect(cs.errors, label: "FAILED #{attrs.id}"); raise "repair failed #{attrs.id}"
  end
end
tz = "America/Toronto"

put!.(%{id: 238, venue_id: 5, title: "Top Rope Meetup — Monday community sessions", kind: "social", cohorts: [], timezone: tz, summary: "Staff-led Monday top-rope sessions for solo climbers and new partners who have passed the belay test.", schedule_kind: "recurring", start_date: ~D[2026-09-14], start_time: ~T[19:00:00], end_time: ~T[22:00:00], audience: [], ages: nil, link: "https://www.joerockheads.com/meetup", link_kind: "event", confidence: "confirmed", caveat: "September 7 is omitted for Labour Day; later calendar coverage is limited to October 19.", sources: ["https://www.joerockheads.com/meetup", "https://app.rockgympro.com/b/widget/?a=calendar&widget_guid=383119ae15544afa902947addd3e9ef6&mode=p"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-14], ~D[2026-09-21], ~D[2026-09-28], ~D[2026-10-05], ~D[2026-10-12], ~D[2026-10-19]], do: %{date: d, start_time: ~T[19:00:00], end_time: ~T[22:00:00], timezone: tz}))

put!.(%{id: 239, venue_id: 5, title: "Run Joe Run Club — return after summer break", kind: "social", cohorts: [], timezone: tz, summary: "Joe Rockhead's run club is announced to return after a short break; details are forthcoming.", schedule_kind: "unscheduled", audience: [], ages: nil, link: "https://www.joerockheads.com/meetup#runclub", link_kind: "event", confidence: "tentative", caveat: "Return date, time, route and price are unknown; summer's Wednesday pattern was not carried forward.", sources: ["https://www.joerockheads.com/meetup#runclub"], checked_on: ~D[2026-09-06], published: false}, [])

put!.(%{id: 240, venue_id: 5, title: "Bulges & Boulders — Joe Rockhead's monthly meetups", kind: "social", cohorts: [], timezone: tz, summary: "Monthly 2SLGBTQ+ and ally climbing meetups at Joe Rockhead's, with orientation for new climbers.", schedule_kind: "recurring", start_date: ~D[2026-09-29], start_time: ~T[18:00:00], audience: ["queer"], ages: nil, link: "https://www.instagram.com/bulgesandboulders/p/DcvwNu4Ee66/", link_kind: "event", confidence: "confirmed", caveat: "September ends at 20:30; later dates have no independently confirmed end time or price.", sources: ["https://app.rockgympro.com/b/widget/?a=calendar&widget_guid=383119ae15544afa902947addd3e9ef6&mode=p", "https://www.instagram.com/bulgesandboulders/p/DcvwNu4Ee66/"], checked_on: ~D[2026-09-06], published: false},
  [%{date: ~D[2026-09-29], start_time: ~T[18:00:00], end_time: ~T[20:30:00], timezone: tz}, %{date: ~D[2026-10-27], start_time: ~T[18:00:00], timezone: tz}, %{date: ~D[2026-11-24], start_time: ~T[18:00:00], timezone: tz}, %{date: ~D[2026-12-29], start_time: ~T[18:00:00], timezone: tz}])

put!.(%{id: 241, venue_id: 5, title: "Technique 101 — upcoming beginner classes", kind: "class", cohorts: [], timezone: tz, summary: "Ninety-minute bouldering technique lessons for adults 14 and over, with registration required.", schedule_kind: "course", start_date: ~D[2026-09-10], end_date: ~D[2026-10-17], audience: ["adult"], ages: "Ages 14+", link: "https://app.rockgympro.com/b/?bo=b86d22de234d46d3901d188c8eee339d", link_kind: "registration", confidence: "confirmed", caveat: "Only the listed dates are confirmed; the offering does not establish a repeating weekly pattern.", sources: ["https://www.joerockheads.com/beginners", "https://app.rockgympro.com/b/?bo=b86d22de234d46d3901d188c8eee339d"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-10], ~D[2026-09-17], ~D[2026-09-24], ~D[2026-10-01], ~D[2026-10-08], ~D[2026-10-15]], do: %{date: d, start_time: ~T[19:00:00], end_time: ~T[20:30:00], timezone: tz}) ++
  (for d <- [~D[2026-09-19], ~D[2026-10-03], ~D[2026-10-10], ~D[2026-10-17]], do: %{date: d, start_time: ~T[15:00:00], end_time: ~T[16:30:00], timezone: tz}))

put!.(%{id: 242, venue_id: 5, title: "Top Rope 101 — upcoming introductory lessons", kind: "class", cohorts: [], timezone: tz, summary: "Introductory 90-minute top-rope lessons covering belaying, harnesses, ropes and facility orientation.", schedule_kind: "course", start_date: ~D[2026-09-08], end_date: ~D[2026-10-18], audience: ["adult"], ages: "Ages 14+", link: "https://app.rockgympro.com/b/?bo=2ad61ee1ba514e46aea8469153efd9fb", link_kind: "registration", confidence: "confirmed", caveat: "Only individually listed dates are included; calendar coverage does not establish a series endpoint.", sources: ["https://www.joerockheads.com/beginners", "https://app.rockgympro.com/b/?bo=2ad61ee1ba514e46aea8469153efd9fb"], checked_on: ~D[2026-09-06], published: false},
  (for d <- [~D[2026-09-08],~D[2026-09-09],~D[2026-09-11],~D[2026-09-15],~D[2026-09-16],~D[2026-09-18],~D[2026-09-22],~D[2026-09-23],~D[2026-09-24],~D[2026-09-29],~D[2026-09-30],~D[2026-10-01],~D[2026-10-02],~D[2026-10-06],~D[2026-10-07],~D[2026-10-08],~D[2026-10-09],~D[2026-10-13],~D[2026-10-14],~D[2026-10-15],~D[2026-10-16]], do: %{date: d, start_time: ~T[18:30:00], end_time: ~T[20:00:00], timezone: tz}) ++
  (for d <- [~D[2026-09-12],~D[2026-09-19],~D[2026-10-03],~D[2026-10-10],~D[2026-10-17]], do: %{date: d, start_time: ~T[10:30:00], end_time: ~T[12:00:00], timezone: tz}) ++
  (for d <- [~D[2026-09-13],~D[2026-09-27],~D[2026-10-04],~D[2026-10-11],~D[2026-10-18]], do: %{date: d, start_time: ~T[14:30:00], end_time: ~T[16:00:00], timezone: tz}))

IO.puts("repair checkpoint complete: #{length(target_ids)} records")
