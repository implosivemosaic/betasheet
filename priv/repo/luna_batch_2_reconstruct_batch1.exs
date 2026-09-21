alias ClimbOntario.Catalogue.{Import, ResearchSource}

a =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

ids = [22, 38, 44, 47, 149, 150, 151, 152, 153]
allowed = (Enum.map(a["first_ten"], & &1["id"]) ++ a["remaining_ids"]) |> MapSet.new()
unless Enum.all?(ids, &MapSet.member?(allowed, &1)), do: raise("manifest")
r = ResearchSource.load()
tz = "America/Toronto"
e = fn id -> Enum.find(r.events, &(&1["id"] == id)) end
src = fn id -> e.(id)["sources"] |> Enum.map(& &1["url"]) |> Enum.uniq() end

put = fn id, attrs, ss ->
  attrs =
    Map.merge(
      %{
        id: id,
        sources: src.(id),
        checked_on: Date.from_iso8601!(String.slice(e.(id)["checked_at"], 0, 10)),
        published: false
      },
      attrs
    )

  case Import.put_listing(attrs, ss) do
    {:ok, l} ->
      IO.puts("#{id}: #{length(l.occurrences)}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "failed #{id}"
  end
end

mk = fn ds, st, et, cohort ->
  Enum.map(ds, &%{date: &1, start_time: st, end_time: et, timezone: tz, cohort: cohort})
end

d = fn s -> String.split(s, ",") |> Enum.map(&Date.from_iso8601!/1) end

q =
  d.(
    "2026-09-14,2026-09-21,2026-09-28,2026-10-05,2026-10-19,2026-10-26,2026-11-02,2026-11-09,2026-11-16,2026-11-23,2026-11-30,2026-12-07,2026-12-14"
  )

w =
  d.(
    "2026-09-09,2026-09-16,2026-09-23,2026-09-30,2026-10-07,2026-10-14,2026-10-21,2026-10-28,2026-11-04,2026-11-11,2026-11-18,2026-11-25,2026-12-02,2026-12-09,2026-12-16"
  )

t =
  d.(
    "2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06,2026-10-13,2026-10-20,2026-10-27,2026-11-03,2026-11-10,2026-11-17,2026-11-24,2026-12-01,2026-12-08,2026-12-15"
  )

h =
  d.(
    "2026-09-10,2026-09-17,2026-09-24,2026-10-01,2026-10-08,2026-10-15,2026-10-22,2026-10-29,2026-11-05,2026-11-12,2026-11-19,2026-11-26,2026-12-03,2026-12-10,2026-12-17"
  )

put.(
  22,
  %{
    venue_id: 4,
    title: "After-school recreational programs — Fall 2026",
    kind: "class",
    cohorts: ["Explorers", "Trailblazers", "Voyagers Tuesday", "Voyagers Thursday"],
    timezone: tz,
    summary: "Fall after-school climbing programmes for Explorers, Trailblazers and Voyagers.",
    schedule_kind: "course",
    start_date: ~D[2026-09-08],
    end_date: ~D[2026-12-17],
    audience: ["youth"],
    ages: "6–12; Voyagers 12+",
    confidence: "confirmed"
  },
  mk.(q, nil, nil, "Explorers") ++
    mk.(w, nil, nil, "Trailblazers") ++
    mk.(t, nil, nil, "Voyagers Tuesday") ++ mk.(h, nil, nil, "Voyagers Thursday")
)

l =
  d.(
    "2026-09-19,2026-09-26,2026-10-03,2026-10-17,2026-10-24,2026-10-31,2026-11-07,2026-11-14,2026-11-21,2026-11-28,2026-12-05,2026-12-12,2026-12-19"
  )

put.(
  38,
  %{
    venue_id: 7,
    title: "Lil Rok — youth recreational program",
    kind: "class",
    cohorts: ["Saturday 10:00", "Saturday 11:30", "Sunday 10:00", "Sunday 11:30"],
    timezone: tz,
    summary: "Ninety-minute youth climbing lessons for ages 6–10.",
    schedule_kind: "course",
    start_date: ~D[2026-09-19],
    end_date: ~D[2026-12-20],
    audience: ["youth"],
    ages: "6–10",
    confidence: "confirmed"
  },
  mk.(l, ~T[10:00:00], ~T[11:30:00], "Saturday 10:00") ++
    mk.(l, ~T[11:30:00], ~T[13:00:00], "Saturday 11:30") ++
    mk.(Enum.map(l, &Date.add(&1, 1)), ~T[10:00:00], ~T[11:30:00], "Sunday 10:00") ++
    mk.(Enum.map(l, &Date.add(&1, 1)), ~T[11:30:00], ~T[13:00:00], "Sunday 11:30")
)

f =
  d.(
    "2026-09-18,2026-09-25,2026-10-02,2026-10-09,2026-10-16,2026-10-23,2026-10-30,2026-11-06,2026-11-13,2026-11-20"
  )

m =
  d.(
    "2026-09-21,2026-09-28,2026-10-05,2026-10-19,2026-10-26,2026-11-02,2026-11-09,2026-11-16,2026-11-23,2026-11-30"
  )

su =
  d.(
    "2026-09-20,2026-09-27,2026-10-04,2026-10-18,2026-10-25,2026-11-01,2026-11-08,2026-11-15,2026-11-22,2026-11-29"
  )

put.(
  44,
  %{
    venue_id: 17,
    title: "Kids Club",
    kind: "class",
    cohorts: ["Junior Friday", "Junior Monday", "Senior Friday", "Senior Monday", "Sunday"],
    timezone: tz,
    summary: "Fall youth climbing programme with five verified cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-18],
    end_date: ~D[2026-11-30],
    audience: ["youth"],
    ages: "6–13",
    confidence: "confirmed"
  },
  mk.(f, ~T[17:00:00], ~T[18:00:00], "Junior Friday") ++
    mk.(m, ~T[17:00:00], ~T[18:00:00], "Junior Monday") ++
    mk.(f, ~T[18:15:00], ~T[19:15:00], "Senior Friday") ++
    mk.(m, ~T[18:15:00], ~T[19:15:00], "Senior Monday") ++
    mk.(su, ~T[09:15:00], ~T[10:15:00], "Sunday")
)

y =
  d.(
    "2026-09-14,2026-09-21,2026-09-28,2026-10-05,2026-10-12,2026-10-19,2026-10-26,2026-11-02,2026-11-09,2026-11-16"
  )

put.(
  47,
  %{
    venue_id: 25,
    title: "Youth Programs — Fall 2026",
    kind: "class",
    cohorts: ["Tykes Monday", "Junior Tuesday", "Senior Wednesday", "Intermediate Thursday"],
    timezone: tz,
    summary: "Fall youth climbing season with four verified age-tier cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-14],
    end_date: ~D[2026-11-20],
    audience: ["youth"],
    ages: "4–17",
    confidence: "confirmed"
  },
  mk.(y, ~T[16:30:00], ~T[18:30:00], "Tykes Monday") ++
    mk.(Enum.map(y, &Date.add(&1, 1)), ~T[17:00:00], ~T[19:00:00], "Junior Tuesday") ++
    mk.(Enum.map(y, &Date.add(&1, 2)), ~T[17:00:00], ~T[19:00:00], "Senior Wednesday") ++
    mk.(Enum.map(y, &Date.add(&1, 3)), ~T[18:45:00], ~T[20:45:00], "Intermediate Thursday")
)

for {id, title, ages, dates, st, et} <- [
      {149, "Recreational Climbing Ages 5–7 — September 2026", "5–7",
       d.("2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06,2026-10-13,2026-10-20"),
       ~T[17:30:00], ~T[18:30:00]},
      {150, "Recreational Climbing Level 1 — September 2026", "8–13",
       d.("2026-09-09,2026-09-16,2026-09-23,2026-09-30,2026-10-07,2026-10-14,2026-10-21"),
       ~T[17:30:00], ~T[19:00:00]},
      {151, "Recreational Climbing Level 2 — September 2026", "8–17",
       d.("2026-09-10,2026-09-17,2026-09-24,2026-10-01,2026-10-08,2026-10-15,2026-10-22"),
       ~T[17:30:00], ~T[19:00:00]},
      {152, "Recreational Climbing Level 3 — September 2026", "8–15",
       d.(
         "2026-09-07,2026-09-10,2026-09-14,2026-09-17,2026-09-21,2026-09-24,2026-09-28,2026-10-01,2026-10-05,2026-10-08,2026-10-12,2026-10-15,2026-10-19,2026-10-22"
       ), ~T[19:15:00], ~T[20:45:00]},
      {153, "Adult Beginner Recreational Course — September 2026", "adult",
       d.("2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06,2026-10-13,2026-10-20"),
       ~T[19:15:00], ~T[21:15:00]}
    ] do
  put.(
    id,
    %{
      venue_id: 40,
      title: title,
      kind: "class",
      cohorts: [],
      timezone: tz,
      summary: title,
      schedule_kind: "course",
      start_date: hd(dates),
      end_date: List.last(dates),
      audience: if(ages == "adult", do: ["adult"], else: ["youth"]),
      ages: ages,
      confidence: "confirmed"
    },
    mk.(dates, st, et, nil)
  )
end

# Complete the remaining Kanata cohorts from the gym-40 handoff.
kanata = d.("2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06,2026-10-13,2026-10-20")
kanata_w = d.("2026-09-09,2026-09-16,2026-09-23,2026-09-30,2026-10-07,2026-10-14,2026-10-21")
kanata_f = d.("2026-09-11,2026-09-18,2026-09-25,2026-10-02,2026-10-09,2026-10-16,2026-10-23")

put.(
  149,
  %{
    venue_id: 40,
    title: "Recreational Climbing Ages 5–7 — September 2026",
    kind: "class",
    cohorts: ["Tuesday 17:30", "Saturday 08:30", "Saturday 10:15"],
    timezone: tz,
    summary: "Seven-week recreational climbing for ages 5–7 in three verified cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-08],
    end_date: ~D[2026-10-24],
    audience: ["youth"],
    ages: "5–7",
    confidence: "confirmed"
  },
  mk.(kanata, ~T[17:30:00], ~T[18:30:00], "Tuesday 17:30") ++
    mk.(
      d.("2026-09-12,2026-09-19,2026-09-26,2026-10-03,2026-10-10,2026-10-17,2026-10-24"),
      ~T[08:30:00],
      ~T[09:30:00],
      "Saturday 08:30"
    ) ++
    mk.(
      d.("2026-09-12,2026-09-19,2026-09-26,2026-10-03,2026-10-10,2026-10-17,2026-10-24"),
      ~T[10:15:00],
      ~T[11:15:00],
      "Saturday 10:15"
    )
)

put.(
  150,
  %{
    venue_id: 40,
    title: "Recreational Climbing Level 1 — September 2026",
    kind: "class",
    cohorts: ["Ages 8–10 Wednesday", "Ages 8–10 Saturday", "Ages 11–13 Tuesday"],
    timezone: tz,
    summary: "Seven-week Level 1 climbing for ages 8–13 in three verified cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-08],
    end_date: ~D[2026-10-24],
    audience: ["youth"],
    ages: "8–13",
    confidence: "confirmed"
  },
  mk.(kanata_w, ~T[17:30:00], ~T[19:00:00], "Ages 8–10 Wednesday") ++
    mk.(
      d.("2026-09-12,2026-09-19,2026-09-26,2026-10-03,2026-10-10,2026-10-17,2026-10-24"),
      ~T[09:45:00],
      ~T[11:15:00],
      "Ages 8–10 Saturday"
    ) ++ mk.(kanata, ~T[18:45:00], ~T[20:15:00], "Ages 11–13 Tuesday")
)

put.(
  151,
  %{
    venue_id: 40,
    title: "Recreational Climbing Level 2 — September 2026",
    kind: "class",
    cohorts: [
      "Ages 8–10 Thursday",
      "Ages 8–10 Saturday",
      "Ages 11–13 Thursday",
      "Ages 11–13 Friday",
      "Ages 14–17 Wednesday"
    ],
    timezone: tz,
    summary: "Seven-week Level 2 climbing for ages 8–17 in five verified cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-09],
    end_date: ~D[2026-10-24],
    audience: ["youth"],
    ages: "8–17",
    confidence: "confirmed"
  },
  mk.(
    d.("2026-09-10,2026-09-17,2026-09-24,2026-10-01,2026-10-08,2026-10-15,2026-10-22"),
    ~T[17:30:00],
    ~T[19:00:00],
    "Ages 8–10 Thursday"
  ) ++
    mk.(
      d.("2026-09-12,2026-09-19,2026-09-26,2026-10-03,2026-10-10,2026-10-17,2026-10-24"),
      ~T[08:30:00],
      ~T[10:00:00],
      "Ages 8–10 Saturday"
    ) ++
    mk.(
      d.("2026-09-10,2026-09-17,2026-09-24,2026-10-01,2026-10-08,2026-10-15,2026-10-22"),
      ~T[19:15:00],
      ~T[20:45:00],
      "Ages 11–13 Thursday"
    ) ++
    mk.(kanata_f, ~T[17:30:00], ~T[19:00:00], "Ages 11–13 Friday") ++
    mk.(kanata_w, ~T[18:00:00], ~T[20:00:00], "Ages 14–17 Wednesday")
)

level3 =
  d.(
    "2026-09-07,2026-09-10,2026-09-14,2026-09-17,2026-09-21,2026-09-24,2026-09-28,2026-10-01,2026-10-05,2026-10-08,2026-10-12,2026-10-15,2026-10-19,2026-10-22"
  )

put.(
  152,
  %{
    venue_id: 40,
    title: "Recreational Climbing Level 3 — September 2026",
    kind: "class",
    cohorts: ["Ages 8–11 Monday/Thursday", "Ages 12–15 Monday/Thursday"],
    timezone: tz,
    summary: "Fourteen-session Level 3 programme in two verified age cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-07],
    end_date: ~D[2026-10-22],
    audience: ["youth"],
    ages: "8–15",
    confidence: "confirmed"
  },
  mk.(level3, ~T[19:30:00], ~T[21:00:00], "Ages 8–11 Monday/Thursday") ++
    mk.(level3, ~T[19:15:00], ~T[20:45:00], "Ages 12–15 Monday/Thursday")
)
