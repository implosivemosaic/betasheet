alias ClimbOntario.Catalogue.{Import, ResearchSource}

m =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

allowed = (Enum.map(m["first_ten"], & &1["id"]) ++ m["remaining_ids"]) |> MapSet.new()
id = 208
unless MapSet.member?(allowed, id), do: raise("target outside worker-2 manifest")
r = ResearchSource.load()

unless Enum.find(r.events, &(&1["id"] == id))["gym_id"] == 43,
  do: raise("research gym lookup mismatch")

s = [
  %{date: ~D[2026-09-06], start_time: ~T[16:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-06], start_time: ~T[17:45:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[12:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[13:30:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[15:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[16:45:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[18:30:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-08], start_time: ~T[20:15:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-12], start_time: ~T[12:30:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-12], start_time: ~T[14:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-12], start_time: ~T[17:45:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-13], start_time: ~T[10:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-13], start_time: ~T[12:30:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-13], start_time: ~T[14:15:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-13], start_time: ~T[16:00:00], timezone: "America/Toronto"},
  %{date: ~D[2026-09-13], start_time: ~T[17:45:00], timezone: "America/Toronto"}
]

a = %{
  id: 208,
  venue_id: 43,
  title: "Kids’ Zone Play Pass — scheduled climbing sessions",
  kind: "class",
  cohorts: [],
  timezone: "America/Toronto",
  summary:
    "Ninety-minute public Kids’ Zone climbing sessions scheduled across selected September dates.",
  schedule_kind: "course",
  start_date: ~D[2026-09-06],
  end_date: ~D[2026-09-13],
  audience: ["youth", "family"],
  ages: nil,
  link: "https://app.rockgympro.com/b/?bo=140d6e1f60da41b3b02820f27df4230d",
  link_kind: "registration",
  confidence: "confirmed",
  caveat:
    "Only individually verified starts are included; September 7 is omitted for Labour Day and some later starts are not yet bookable.",
  sources: [
    "https://app.rockgympro.com/b/?bo=140d6e1f60da41b3b02820f27df4230d",
    "https://www.altrock.co/products/products/play-pass/",
    "https://www.instagram.com/alt._rock/reel/DSQASImkQSA/"
  ],
  checked_on: ~D[2026-09-06],
  published: false
}

case Import.put_listing(a, s) do
  {:ok, l} ->
    IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")

  {:error, c} ->
    IO.inspect(c.errors)
    raise "repair failed"
end
