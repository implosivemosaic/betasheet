alias ClimbOntario.Catalogue.{Import, ResearchSource}

assignment =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

ids = [
  3,
  4,
  18,
  22,
  27,
  29,
  37,
  38,
  44,
  45,
  46,
  47,
  48,
  49,
  54,
  58,
  136,
  149,
  150,
  151,
  152,
  153,
  159,
  230,
  231,
  232,
  253,
  258,
  259,
  269,
  270,
  279,
  280,
  298,
  310,
  25,
  43
]

allowed =
  (Enum.map(assignment["first_ten"], & &1["id"]) ++ assignment["remaining_ids"]) |> MapSet.new()

unless Enum.all?(ids, &MapSet.member?(allowed, &1)), do: raise("manifest ownership")
r = ResearchSource.load()
tz = "America/Toronto"
event = fn id -> Enum.find(r.events, &(&1["id"] == id)) end
sources = fn id -> event.(id) |> Map.fetch!("sources") |> Enum.map(& &1["url"]) |> Enum.uniq() end
checked = fn id -> event.(id)["checked_at"] |> String.slice(0, 10) |> Date.from_iso8601!() end

put = fn id, attrs, sessions ->
  attrs =
    Map.merge(
      %{id: id, sources: sources.(id), checked_on: checked.(id), published: false},
      attrs
    )

  result =
    if is_nil(sessions), do: Import.put_listing(attrs), else: Import.put_listing(attrs, sessions)

  case result do
    {:ok, l} ->
      IO.puts("repaired #{id}: #{length(l.occurrences)} occurrences, published=#{l.published}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "failed #{id}"
  end
end

s = fn dates, st, et ->
  Enum.map(dates, &%{date: &1, start_time: st, end_time: et, timezone: tz})
end

d = fn text -> String.split(text, ",") |> Enum.map(&Date.from_iso8601!/1) end

for {id, attrs} <- [
      {3,
       %{
         schedule_kind: "one_off",
         start_date: ~D[2026-08-14],
         start_time: ~T[17:00:00],
         end_time: ~T[18:30:00]
       }},
      {4,
       %{
         schedule_kind: "one_off",
         start_date: ~D[2026-07-25],
         start_time: ~T[10:00:00],
         end_time: ~T[12:00:00]
       }},
      {18,
       %{
         schedule_kind: "unscheduled",
         start_date: nil,
         end_date: nil,
         start_time: nil,
         end_time: nil
       }},
      {22, %{schedule_kind: "course"}},
      {27, %{schedule_kind: "course"}},
      {29, %{schedule_kind: "unscheduled", start_date: nil, end_date: nil}},
      {37,
       %{
         schedule_kind: "course",
         start_date: ~D[2026-09-11],
         end_date: ~D[2026-09-18],
         start_time: nil,
         end_time: nil,
         caveat: "The posted check-in window is not an organized event duration."
       }},
      {38, %{schedule_kind: "course"}},
      {44, %{schedule_kind: "course"}},
      {45, %{schedule_kind: "recurring", start_time: ~T[18:00:00], end_time: ~T[23:00:00]}},
      {46, %{schedule_kind: "one_off"}},
      {47, %{schedule_kind: "course"}},
      {48, %{schedule_kind: "course"}},
      {49, %{schedule_kind: "recurring"}},
      {54, %{schedule_kind: "course"}},
      {58,
       %{
         schedule_kind: "unscheduled",
         start_date: nil,
         end_date: nil,
         start_time: nil,
         end_time: nil
       }},
      {136,
       %{
         schedule_kind: "unscheduled",
         start_date: nil,
         end_date: nil,
         start_time: nil,
         end_time: nil
       }},
      {149, %{schedule_kind: "course"}},
      {150, %{schedule_kind: "course"}},
      {151, %{schedule_kind: "course"}},
      {152, %{schedule_kind: "course"}},
      {153, %{schedule_kind: "course"}},
      {159, %{schedule_kind: "course"}},
      {230, %{schedule_kind: "multi_day"}},
      {231, %{schedule_kind: "recurring"}},
      {232,
       %{
         schedule_kind: "unscheduled",
         start_date: nil,
         end_date: nil,
         start_time: nil,
         end_time: nil
       }},
      {253, %{schedule_kind: "one_off"}},
      {258, %{schedule_kind: "course", start_date: ~D[2026-09-07], end_date: ~D[2026-09-13]}},
      {259, %{schedule_kind: "recurring"}},
      {269, %{schedule_kind: "course"}},
      {270, %{schedule_kind: "multi_day"}},
      {279, %{schedule_kind: "recurring"}},
      {280, %{schedule_kind: "recurring"}},
      {298, %{schedule_kind: "one_off"}},
      {310, %{schedule_kind: "multi_day"}}
    ] do
  sessions =
    case id do
      37 ->
        [%{date: ~D[2026-09-11], timezone: tz}, %{date: ~D[2026-09-18], timezone: tz}]

      45 ->
        s.(
          d.(
            "2026-09-11,2026-09-18,2026-09-25,2026-10-02,2026-10-09,2026-10-16,2026-10-23,2026-10-30"
          ),
          ~T[18:00:00],
          ~T[23:00:00]
        )

      46 ->
        s.(d.("2026-08-26"), ~T[19:00:00], ~T[21:00:00])

      49 ->
        s.(
          d.("2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06"),
          ~T[19:00:00],
          ~T[21:00:00]
        )

      54 ->
        s.(d.("2026-10-01,2026-10-08,2026-10-15,2026-10-22"), ~T[18:00:00], ~T[19:30:00])

      159 ->
        s.(d.("2026-09-20,2026-09-27,2026-10-04"), ~T[09:00:00], ~T[11:00:00])

      231 ->
        s.(d.("2026-09-27,2026-10-25,2026-11-29,2026-12-27"), ~T[17:00:00], ~T[19:00:00])

      253 ->
        s.(d.("2026-11-06"), ~T[17:00:00], ~T[23:00:00])

      298 ->
        [%{date: ~D[2027-01-16], timezone: tz}]

      310 ->
        [%{date: ~D[2027-02-06], timezone: tz}, %{date: ~D[2027-02-07], timezone: tz}]

      230 ->
        [%{date: ~D[2026-10-03], timezone: tz}, %{date: ~D[2026-10-04], timezone: tz}]

      _ ->
        nil
    end

  put.(id, attrs, sessions)
end

put.(
  25,
  %{
    venue_id: 5,
    title: "Coordination Clinic with EJ",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary:
      "A four-week coordination and falling-technique clinic for climbers aged 14 and over.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    audience: ["adult"],
    ages: "14+",
    confidence: "tentative",
    caveat: nil
  },
  []
)

put.(
  43,
  %{
    venue_id: 11,
    title: "Fall Shoe Swap 2026",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary:
      "Bring climbing shoes without holes and swap for another pair at Boulderz Etobicoke.",
    schedule_kind: "one_off",
    start_date: ~D[2026-09-12],
    start_time: nil,
    end_time: nil,
    audience: [],
    confidence: "tentative",
    caveat:
      "Published sources conflict between 10:00–15:00 and 18:00–21:00; event time is unconfirmed."
  },
  [%{date: ~D[2026-09-12], start_time: nil, end_time: nil, timezone: tz}]
)

IO.puts(
  "explicit repair pass complete: #{length(ids)} IDs; content verification remains required"
)
