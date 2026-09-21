alias ClimbOntario.Catalogue.{Import, ResearchSource}

m =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

allowed = (Enum.map(m["first_ten"], & &1["id"]) ++ m["remaining_ids"]) |> MapSet.new()
targets = [227, 228]

unless Enum.all?(targets, &MapSet.member?(allowed, &1)),
  do: raise("target outside worker-2 manifest")

r = ResearchSource.load()
e = Map.new(r.events, &{&1["id"], &1})
unless Enum.all?(targets, &(e[&1]["gym_id"] == 54)), do: raise("research gym lookup mismatch")

put! = fn a, s ->
  unless MapSet.member?(allowed, a.id), do: raise("unguarded write")

  case Import.put_listing(a, s) do
    {:ok, l} ->
      IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "repair failed"
  end
end

tz = "America/Toronto"

put!.(
  %{
    id: 227,
    venue_id: 54,
    title: "Grit Gauntlet 2026 — Pursuit Climbing pit stop",
    kind: "competition",
    cohorts: [],
    timezone: tz,
    summary: "Grit Gauntlet climbing competition stop at Pursuit Climbing on November 8, 2026.",
    schedule_kind: "one_off",
    start_date: ~D[2026-11-08],
    start_time: ~T[12:00:00],
    end_time: ~T[18:00:00],
    audience: [],
    ages: nil,
    link: "https://square.link/u/MneqJi5m",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: nil,
    sources: [
      "https://square.link/u/MneqJi5m",
      "https://www.instagram.com/grit.gauntlet/",
      "https://www.instagram.com/grit.gauntlet/p/DcZcwHfODc1/"
    ],
    checked_on: ~D[2026-09-06],
    published: false,
    ocf: false
  },
  [%{date: ~D[2026-11-08], start_time: ~T[12:00:00], end_time: ~T[18:00:00], timezone: tz}]
)

put!.(
  %{
    id: 228,
    venue_id: 54,
    title: "New Heights Comp",
    kind: "competition",
    cohorts: [],
    timezone: tz,
    summary: "New Heights climbing competition at Pursuit Climbing on October 24, 2026.",
    schedule_kind: "one_off",
    start_date: ~D[2026-10-24],
    start_time: ~T[10:00:00],
    end_time: ~T[17:00:00],
    audience: [],
    ages: nil,
    link: "https://pursuit.portal.approach.app/event/525/booking/18552/embed",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: nil,
    sources: [
      "https://pursuit.portal.approach.app/event/525/booking/18552/embed",
      "https://pursuit.portal.approach.app/schedule/embed?scheduleView=list&startDate=2026-10-01&endDate=2026-11-30&locationIds=1"
    ],
    checked_on: ~D[2026-09-06],
    published: false,
    ocf: false
  },
  [%{date: ~D[2026-10-24], start_time: ~T[10:00:00], end_time: ~T[17:00:00], timezone: tz}]
)
