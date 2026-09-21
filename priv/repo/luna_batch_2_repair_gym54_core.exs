alias ClimbOntario.Catalogue.{Import, ResearchSource}

m =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

allowed = (Enum.map(m["first_ten"], & &1["id"]) ++ m["remaining_ids"]) |> MapSet.new()
ids = 12..16 |> Enum.to_list()
unless Enum.all?(ids, &MapSet.member?(allowed, &1)), do: raise("manifest")
r = ResearchSource.load()
e = Map.new(r.events, &{&1["id"], &1})
unless Enum.all?(ids, &(e[&1]["gym_id"] == 54)), do: raise("gym")

put! = fn a, s ->
  case Import.put_listing(a, s) do
    {:ok, l} ->
      IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "failed"
  end
end

tz = "America/Toronto"

band = [
  ~D[2026-09-16],
  ~D[2026-09-23],
  ~D[2026-09-30],
  ~D[2026-10-07],
  ~D[2026-10-14],
  ~D[2026-10-21],
  ~D[2026-10-28],
  ~D[2026-11-04]
]

put!.(
  %{
    id: 12,
    venue_id: 54,
    title: "Boulder Bandits — Fall 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Eight-week beginner youth climbing programme for ages 6–9.",
    schedule_kind: "course",
    start_date: ~D[2026-09-16],
    end_date: ~D[2026-11-04],
    start_time: ~T[17:15:00],
    end_time: ~T[18:15:00],
    audience: ["youth"],
    ages: "Born 2017–2020",
    link: "https://pursuit.portal.approach.app/event/518/embed",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "Sold out when checked.",
    sources: [
      "https://pursuit.portal.approach.app/event/518/embed",
      "https://pursuit.portal.approach.app/schedule/embed",
      "https://www.instagram.com/pursuitclimbing/p/DcT7nLpG7jV/"
    ],
    checked_on: ~D[2026-09-06],
    published: false
  },
  Enum.map(band, &%{date: &1, start_time: ~T[17:15:00], end_time: ~T[18:15:00], timezone: tz})
)

put!.(
  %{
    id: 13,
    venue_id: 54,
    title: "Summit Seekers — Fall 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Eight-week beginner and intermediate youth climbing programme for ages 10–13.",
    schedule_kind: "course",
    start_date: ~D[2026-09-16],
    end_date: ~D[2026-11-04],
    start_time: ~T[18:30:00],
    end_time: ~T[19:30:00],
    audience: ["youth"],
    ages: "Born 2013–2016",
    link: "https://pursuit.portal.approach.app/event/520/embed",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "Live overview dates conflict with stale body copy; sold out when checked.",
    sources: [
      "https://pursuit.portal.approach.app/event/520/embed",
      "https://pursuit.portal.approach.app/schedule/embed"
    ],
    checked_on: ~D[2026-09-06],
    published: false
  },
  Enum.map(band, &%{date: &1, start_time: ~T[18:30:00], end_time: ~T[19:30:00], timezone: tz})
)

put!.(
  %{
    id: 14,
    venue_id: 54,
    title: "Movement With Adam",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary:
      "Weekly all-level guided workout with coach Adam focused on strength and climbing longevity.",
    schedule_kind: "recurring",
    start_time: ~T[19:30:00],
    end_time: ~T[21:00:00],
    audience: [],
    ages: nil,
    link: "https://pursuit.portal.approach.app/event/505/booking/18527/embed",
    link_kind: "registration",
    confidence: "confirmed",
    caveat:
      "Only September 9–30 dates and current 19:30 time were verified; generic page copy conflicts.",
    sources: [
      "https://pursuit.portal.approach.app/event/505/booking/18527/embed",
      "https://pursuit.portal.approach.app/schedule/embed"
    ],
    checked_on: ~D[2026-09-06],
    published: false
  },
  Enum.map(
    [~D[2026-09-09], ~D[2026-09-16], ~D[2026-09-23], ~D[2026-09-30]],
    &%{date: &1, start_time: ~T[19:30:00], end_time: ~T[21:00:00], timezone: tz}
  )
)

put!.(
  %{
    id: 15,
    venue_id: 54,
    title: "Youth Climb Club",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Ongoing weekly Thursday coaching for experienced youth climbers.",
    schedule_kind: "recurring",
    start_time: ~T[17:30:00],
    end_time: ~T[19:00:00],
    audience: ["youth"],
    ages: nil,
    link: "https://pursuit.portal.approach.app/event/521/booking/18528/embed",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "No series bounds inferred; ongoing membership programme.",
    sources: [
      "https://pursuit.portal.approach.app/event/521/booking/18528/embed",
      "https://www.instagram.com/pursuitclimbing/p/DcT7nLpG7jV/"
    ],
    checked_on: ~D[2026-09-06],
    published: false
  },
  Enum.map(
    [~D[2026-09-10], ~D[2026-09-17], ~D[2026-09-24], ~D[2026-10-01]],
    &%{date: &1, start_time: ~T[17:30:00], end_time: ~T[19:00:00], timezone: tz}
  )
)

put!.(
  %{
    id: 16,
    venue_id: 54,
    title: "Empower Climb — Labour Day weekend",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Empower Climb is confirmed for Labour Day Sunday at Pursuit Climbing.",
    schedule_kind: "one_off",
    start_date: ~D[2026-09-06],
    audience: [],
    ages: nil,
    link: "https://www.instagram.com/pursuitclimbing/p/DcvkJsAhZ-w/",
    link_kind: "event",
    confidence: "tentative",
    caveat: "Opening hours are not event times; event time, eligibility and format are unknown.",
    sources: ["https://www.instagram.com/pursuitclimbing/p/DcvkJsAhZ-w/"],
    checked_on: ~D[2026-09-06],
    published: false
  },
  [%{date: ~D[2026-09-06], timezone: tz}]
)
