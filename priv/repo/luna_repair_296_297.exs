alias ClimbOntario.Catalogue.Import

tz = "America/Toronto"
put! = fn attrs, sessions ->
  case Import.put_listing(attrs, sessions) do
    {:ok, listing} -> IO.puts("repaired #{listing.id}: #{length(listing.occurrences)} occurrences")
    {:error, cs} -> IO.inspect(cs); raise "repair failed"
  end
end

t = fn date, start, finish -> %{date: date, start_time: start, end_time: finish, timezone: tz} end
slot = fn date, start, minutes ->
  {h, m, s} = Time.to_erl(start)
  finish = Time.add(start, minutes * 60)
  t.(date, start, finish)
end

belay = [
  {~D[2026-09-08], [~T[12:15:00], ~T[14:45:00], ~T[17:15:00], ~T[19:45:00]]},
  {~D[2026-09-09], [~T[09:45:00], ~T[12:15:00], ~T[14:45:00], ~T[19:45:00]]},
  {~D[2026-09-13], [~T[12:30:00]]},
  {~D[2026-09-14], [~T[17:15:00]]},
  {~D[2026-09-15], [~T[12:15:00], ~T[14:45:00], ~T[17:15:00], ~T[19:45:00]]},
  {~D[2026-09-16], [~T[09:45:00], ~T[12:15:00], ~T[14:45:00], ~T[19:45:00]]},
  {~D[2026-09-19], [~T[10:00:00], ~T[12:30:00], ~T[15:00:00]]},
  {~D[2026-09-20], [~T[12:30:00], ~T[15:00:00]]},
  {~D[2026-09-21], [~T[17:15:00]]},
  {~D[2026-09-22], [~T[12:15:00], ~T[14:45:00], ~T[17:15:00], ~T[19:45:00]]},
  {~D[2026-09-23], [~T[09:45:00], ~T[12:15:00], ~T[14:45:00]]},
  {~D[2026-09-24], [~T[12:15:00], ~T[14:45:00], ~T[17:15:00], ~T[19:45:00]]},
  {~D[2026-09-25], [~T[12:15:00], ~T[14:45:00], ~T[17:15:00], ~T[19:45:00]]},
  {~D[2026-09-26], [~T[15:00:00]]},
  {~D[2026-09-27], [~T[10:00:00], ~T[12:30:00], ~T[15:00:00]]}
] |> Enum.flat_map(fn {d, starts} -> Enum.map(starts, &slot.(d, &1, 120)) end)

put!.(%{id: 296, venue_id: 33, title: "Top Rope Belay Lessons — September 2026", kind: "class", timezone: tz,
  location_kind: "venue", summary: "Small-group top-rope belay lessons for climbers aged 13 and older.",
  schedule_kind: "recurring", schedule_note: "Confirmed September 8–27 lesson slots are shown; later calendar markers were not individually inspected.",
  audience: ["adult"], ages: "13+", link: "https://app.rockgympro.com/b/?bo=fa949769e4b64854910551fe38f0431a", link_kind: "registration",
  confidence: "check", sources: ["https://www.junctionclimbing.com/top-rope-belay-lessons", "https://app.rockgympro.com/b/?bo=fa949769e4b64854910551fe38f0431a"], checked_on: ~D[2026-09-06], published: false}, belay)

get_into = Enum.flat_map([
  {~D[2026-09-08], [~T[12:15:00], ~T[13:30:00], ~T[14:45:00], ~T[16:00:00], ~T[17:15:00], ~T[18:30:00], ~T[19:45:00], ~T[21:00:00]]},
  {~D[2026-09-09], [~T[09:45:00], ~T[11:00:00], ~T[12:15:00], ~T[13:30:00], ~T[14:45:00], ~T[19:45:00], ~T[21:00:00]]},
  {~D[2026-09-14], [~T[17:15:00], ~T[18:30:00]]},
  {~D[2026-09-15], [~T[12:15:00], ~T[13:30:00], ~T[14:45:00], ~T[16:00:00], ~T[17:15:00], ~T[18:30:00], ~T[19:45:00], ~T[21:00:00]]},
  {~D[2026-09-16], [~T[09:45:00], ~T[11:00:00], ~T[12:15:00], ~T[13:30:00], ~T[14:45:00], ~T[19:45:00], ~T[21:00:00]]}
], fn {d, starts} -> Enum.map(starts, &slot.(d, &1, 60)) end)

put!.(%{id: 297, venue_id: 33, title: "Get into Climbing Lessons — September 2026", kind: "class", timezone: tz,
  location_kind: "venue", summary: "One-hour introductory climbing lessons for first-time and very new climbers aged 13 and older.",
  schedule_kind: "recurring", schedule_note: "Confirmed September 8–16 lesson slots are shown; later September calendar markers were visible but their individual rows were not inspected.",
  audience: ["adult"], ages: "13+", link: "https://app.rockgympro.com/b/?bo=4f9693ab85e244ae9fd5c625a45f2b08", link_kind: "registration",
  confidence: "check", sources: ["https://www.junctionclimbing.com/climbing-lessons", "https://app.rockgympro.com/b/?bo=4f9693ab85e244ae9fd5c625a45f2b08"], checked_on: ~D[2026-09-06], published: false}, get_into)
