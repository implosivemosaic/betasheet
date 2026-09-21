alias ClimbOntario.Catalogue.{Import, ResearchSource}

m =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

allowed = (Enum.map(m["first_ten"], & &1["id"]) ++ m["remaining_ids"]) |> MapSet.new()
targets = Enum.to_list(160..166)

unless Enum.all?(targets, &MapSet.member?(allowed, &1)),
  do: raise("target outside worker-2 manifest")

r = ResearchSource.load()
e = Map.new(r.events, &{&1["id"], &1})
unless Enum.all?(targets, &(e[&1]["gym_id"] == 43)), do: raise("research gym lookup mismatch")

put! = fn a, s ->
  case Import.put_listing(a, s) do
    {:ok, l} ->
      IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences, published=#{l.published}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "repair failed"
  end
end

tz = "America/Toronto"
alt = "https://www.altrock.co/services/youth-offerings/youth-climbing-lessons-ages-5-14-6-weeks/"

put!.(
  %{
    id: 160,
    venue_id: 43,
    title: "Wee Rock — September 2026",
    kind: "class",
    cohorts: ["Tuesday", "Wednesday"],
    timezone: tz,
    summary: "Fifty-minute youth climbing lessons for ages 3–5 in Tuesday and Wednesday cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-15],
    end_date: ~D[2026-10-21],
    audience: ["youth"],
    ages: "Ages 3–5",
    link: "https://app.rockgympro.com/b/?bo=87aa9f94434449f1a43489476a56136d",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "All listed dates are full; cohort calendars are explicit.",
    sources: ["https://app.rockgympro.com/b/?bo=87aa9f94434449f1a43489476a56136d", alt],
    checked_on: ~D[2026-09-06],
    published: false
  },
  for(
    d <- Date.range(~D[2026-09-15], ~D[2026-10-20]),
    Date.day_of_week(d) == 2,
    do: %{date: d, start_time: ~T[16:45:00], end_time: ~T[17:35:00], timezone: tz}
  ) ++
    for(
      d <- Date.range(~D[2026-09-16], ~D[2026-10-21]),
      Date.day_of_week(d) == 3,
      do: %{date: d, start_time: ~T[16:45:00], end_time: ~T[17:35:00], timezone: tz}
    )
)

put!.(
  %{
    id: 161,
    venue_id: 43,
    title: "Alt. Rock Youth Lessons — September 2026",
    kind: "class",
    cohorts: ["Monday", "Tuesday", "Thursday"],
    timezone: tz,
    summary: "Six-week youth climbing lessons for ages 5–14 across three cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-14],
    end_date: ~D[2026-10-26],
    audience: ["youth"],
    ages: "Ages 5–14",
    link: "https://app.rockgympro.com/b/?bo=d985a9f0a9a84c63bb13aa9c93b5438c",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "Thanksgiving Monday omission is preserved.",
    sources: ["https://app.rockgympro.com/b/?bo=d985a9f0a9a84c63bb13aa9c93b5438c", alt],
    checked_on: ~D[2026-09-06],
    published: false
  },
  for(
    d <- Date.range(~D[2026-09-14], ~D[2026-10-26]),
    Date.day_of_week(d) == 1 and d != ~D[2026-10-12],
    do: %{
      date: d,
      start_time: ~T[16:45:00],
      end_time: ~T[17:45:00],
      cohort: "Monday",
      timezone: tz
    }
  ) ++
    for(
      d <- Date.range(~D[2026-09-15], ~D[2026-10-20]),
      Date.day_of_week(d) == 2,
      do: %{
        date: d,
        start_time: ~T[17:45:00],
        end_time: ~T[18:45:00],
        cohort: "Tuesday",
        timezone: tz
      }
    ) ++
    for(
      d <- Date.range(~D[2026-09-17], ~D[2026-10-22]),
      Date.day_of_week(d) == 4,
      do: %{
        date: d,
        start_time: ~T[16:45:00],
        end_time: ~T[17:45:00],
        cohort: "Thursday",
        timezone: tz
      }
    )
)

put!.(
  %{
    id: 162,
    venue_id: 43,
    title: "Pop Rock — September 2026",
    kind: "class",
    cohorts: ["Monday", "Thursday", "Friday"],
    timezone: tz,
    summary: "Six-week youth climbing lessons for ages 5–14 across three cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-14],
    end_date: ~D[2026-10-26],
    audience: ["youth"],
    ages: "Ages 5–14",
    link: "https://app.rockgympro.com/b/?bo=eb58be5ba4714fc1b965da98dc82d3a5",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "Monday Thanksgiving omission is preserved; Monday and Thursday cohorts are full.",
    sources: ["https://app.rockgympro.com/b/?bo=eb58be5ba4714fc1b965da98dc82d3a5", alt],
    checked_on: ~D[2026-09-06],
    published: false
  },
  for(
    d <- Date.range(~D[2026-09-14], ~D[2026-10-26]),
    Date.day_of_week(d) == 1 and d != ~D[2026-10-12],
    do: %{
      date: d,
      start_time: ~T[18:00:00],
      end_time: ~T[19:15:00],
      cohort: "Monday",
      timezone: tz
    }
  ) ++
    for(
      d <- Date.range(~D[2026-09-17], ~D[2026-10-22]),
      Date.day_of_week(d) == 4,
      do: %{
        date: d,
        start_time: ~T[18:00:00],
        end_time: ~T[19:15:00],
        cohort: "Thursday",
        timezone: tz
      }
    ) ++
    for(
      d <- Date.range(~D[2026-09-18], ~D[2026-10-23]),
      Date.day_of_week(d) == 5,
      do: %{
        date: d,
        start_time: ~T[16:30:00],
        end_time: ~T[17:45:00],
        cohort: "Friday",
        timezone: tz
      }
    )
)

put!.(
  %{
    id: 163,
    venue_id: 43,
    title: "Punk Rock — September 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Six Wednesday youth climbing lessons for ages 5–14.",
    schedule_kind: "course",
    start_date: ~D[2026-09-16],
    end_date: ~D[2026-10-21],
    start_time: ~T[17:45:00],
    end_time: ~T[19:00:00],
    audience: ["youth"],
    ages: "Ages 5–14",
    link: "https://app.rockgympro.com/b/?bo=9c1618d09b7d47d0bc56bef682e453a1",
    link_kind: "registration",
    confidence: "confirmed",
    caveat: "All listed dates are full.",
    sources: ["https://app.rockgympro.com/b/?bo=9c1618d09b7d47d0bc56bef682e453a1", alt],
    checked_on: ~D[2026-09-06],
    published: false
  },
  for(
    d <- [
      ~D[2026-09-16],
      ~D[2026-09-23],
      ~D[2026-09-30],
      ~D[2026-10-07],
      ~D[2026-10-14],
      ~D[2026-10-21]
    ],
    do: %{date: d, start_time: ~T[17:45:00], end_time: ~T[19:00:00], timezone: tz}
  )
)

for {id, title, url} <- [
      {164, "Barrie Boulder League — September 21", "85d8be66729c4b639fbcb84e9b48b191"},
      {165, "Youth Rec Comp — September 21", "94ddc28143254139ac18d6fb5e50e5e7"}
    ] do
  put!.(
    %{
      id: id,
      venue_id: 43,
      title: title,
      kind: "competition",
      cohorts: [],
      timezone: tz,
      summary: "Youth climbing competition at Alt. Rock Barrie.",
      schedule_kind: "one_off",
      start_date: ~D[2026-09-21],
      start_time: if(id == 164, do: ~T[17:30:00], else: ~T[16:30:00]),
      end_time: if(id == 164, do: ~T[21:30:00], else: ~T[17:30:00]),
      audience: ["youth"],
      ages: nil,
      link: "https://app.rockgympro.com/b/?bo=" <> url,
      link_kind: "registration",
      confidence: "confirmed",
      caveat: nil,
      sources: [
        "https://app.rockgympro.com/b/?bo=" <> url,
        "https://www.altrock.co/services/events/the-barrie-boulder-league-youth-rec-comp/"
      ],
      checked_on: ~D[2026-09-06],
      published: false
    },
    [
      %{
        date: ~D[2026-09-21],
        start_time: if(id == 164, do: ~T[17:30:00], else: ~T[16:30:00]),
        end_time: if(id == 164, do: ~T[21:30:00], else: ~T[17:30:00]),
        timezone: tz
      }
    ]
  )
end

put!.(
  %{
    id: 166,
    venue_id: 43,
    title: "Adult Climbing Lessons — Tuesday Classes",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Weekly 75-minute adult climbing lessons offered Tuesdays.",
    schedule_kind: "recurring",
    start_time: ~T[17:00:00],
    end_time: ~T[18:15:00],
    audience: ["adult"],
    ages: nil,
    link: "https://app.rockgympro.com/b/?bo=eedda33939494597aa9e9e643bba15ce",
    link_kind: "registration",
    confidence: "tentative",
    caveat: "The next cohort start date is not published; contact the gym.",
    sources: [
      "https://app.rockgympro.com/b/?bo=eedda33939494597aa9e9e643bba15ce",
      "https://www.altrock.co/services/adult-offerings/adult-climbing-lessons/"
    ],
    checked_on: ~D[2026-09-06],
    published: false
  },
  []
)

IO.puts("repair checkpoint complete: gym 43 IDs 160–166")
