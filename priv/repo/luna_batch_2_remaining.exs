alias ClimbOntario.{Catalogue, Repo}
alias ClimbOntario.Catalogue.{Import, ResearchSource}

assignment = "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
ids = assignment |> File.read!() |> Jason.decode!() |> get_in(["2", "remaining_ids"])
research = ResearchSource.load()
by_id = Map.new(research.events, &{&1["id"], &1})
gyms = Map.new(research.gyms, &{&1["id"], &1})
editorial =
  ["part-1.json", "part-2.json"]
  |> Enum.map(&File.read!(Path.join("priv/catalogue/editorial", &1)) |> Jason.decode!())
  |> Enum.reduce(%{}, &Map.merge(&2, &1))

parse_date = fn nil -> nil; s -> Date.from_iso8601!(s) end
parse_time = fn nil -> nil; s -> Time.from_iso8601!(s <> ":00") end
kind_for = fn category ->
  cond do
    String.contains?(category, "competition") -> "competition"
    String.contains?(category, "social") or String.contains?(category, "community") or String.contains?(category, "meetup") -> "social"
    String.contains?(category, "camp") -> "camp"
    true -> "class"
  end
end
ages_for = fn e ->
  case editorial[to_string(e["id"])] do
    %{"ages" => ages} -> ages
    _ -> nil
  end
end
summary_for = fn e ->
  raw_title = e["title"]
  title = if String.valid?(raw_title), do: raw_title |> String.replace(~r/\s*[—-]\s*(registration announcement|forthcoming registration|dates coming soon)\z/i, ""), else: "listing #{e["id"]}"
  cond do
    String.contains?(String.downcase(e["category"]), "competition") -> "A climbing competition: #{title}."
    String.contains?(String.downcase(e["category"]), "camp") -> "A climbing camp: #{title}."
    String.contains?(String.downcase(e["category"]), "social") -> "A climbing social event: #{title}."
    true -> "A climbing programme or lesson: #{title}."
  end
end

put! = fn e ->
  id = e["id"]
  kind = kind_for.(e["category"])
  sd = parse_date.(e["start_date"])
  ed = parse_date.(e["end_date"])
  st = parse_time.(e["start_time"])
  et = parse_time.(e["end_time"])
  schedule =
    cond do
      is_nil(sd) -> "unscheduled"
      kind == "competition" and ed != sd and not is_nil(ed) -> "multi_day"
      e["status"] == "recurring" -> "recurring"
      ed != sd and not is_nil(ed) -> "course"
      true -> "one_off"
    end
  g = gyms[e["gym_id"]]
  sources = Enum.map(e["sources"], & &1["url"])
  link = e["registration_url"] || List.first(sources) || g["website"]
  audiences =
    [
      if(String.match?(String.downcase((e["description"] || "") <> " " <> (e["title"] || "")), ~r/\b(youth|kid|child|teen|age[sd]?\s*\d|u\d)/), do: "youth"),
      if(String.match?(String.downcase((e["description"] || "") <> " " <> (e["title"] || "")), ~r/\badult|18\+/), do: "adult"),
      if(String.match?(String.downcase(e["category"]), ~r/family/), do: "family")
    ] |> Enum.reject(&is_nil/1) |> Enum.uniq()
  attrs = %{
    id: id, venue_id: e["gym_id"], title: e["title"], kind: kind, ocf: if(kind == "competition", do: String.contains?(String.downcase(e["title"]), "ocf"), else: nil),
    cohorts: [], timezone: e["timezone"], summary: summary_for.(e), schedule_kind: schedule,
    start_date: if(schedule in ["one_off", "multi_day", "course"], do: sd), end_date: if(schedule in ["multi_day", "course"], do: ed),
    start_time: if(schedule == "one_off", do: st), end_time: if(schedule == "one_off", do: et),
    audience: audiences, ages: ages_for.(e), link: link, link_kind: if(e["registration_url"], do: "registration", else: "event"),
    confidence: if(is_nil(sd), do: "tentative", else: "confirmed"), caveat: nil, sources: sources,
    checked_on: e["checked_at"] |> String.slice(0, 10) |> Date.from_iso8601!(), published: false
  }
  sessions =
    cond do
      schedule == "one_off" -> [%{date: sd, start_time: st, end_time: et, timezone: e["timezone"]}]
      schedule == "multi_day" -> [%{date: sd, timezone: e["timezone"]}, %{date: ed, timezone: e["timezone"]}]
      schedule == "recurring" and not is_nil(sd) -> [%{date: sd, start_time: st, end_time: et, timezone: e["timezone"]}]
      true -> []
    end
  case Import.put_listing(attrs, sessions) do
    {:ok, l} -> IO.puts("imported #{id} (#{schedule}), occurrences=#{length(l.occurrences)}")
    {:error, cs} -> IO.inspect(cs.errors, label: "FAILED #{id}"); raise "import failed #{id}"
  end
end

Enum.each(ids, fn id -> put!.(by_id[id]) end)
IO.puts("remaining worker 2 complete: #{length(ids)} IDs")
