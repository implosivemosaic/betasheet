alias ClimbOntario.Catalogue.{Import, ResearchSource}

a =
  "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json"
  |> File.read!()
  |> Jason.decode!()
  |> Map.fetch!("2")

ids = [
  3,
  4,
  18,
  27,
  29,
  37,
  45,
  46,
  48,
  49,
  54,
  58,
  136,
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
  310
]

allowed = (Enum.map(a["first_ten"], & &1["id"]) ++ a["remaining_ids"]) |> MapSet.new()
unless Enum.all?(ids, &MapSet.member?(allowed, &1)), do: raise("manifest")
r = ResearchSource.load()
tz = "America/Toronto"
e = fn id -> Enum.find(r.events, &(&1["id"] == id)) end
src = fn id -> e.(id)["sources"] |> Enum.map(& &1["url"]) |> Enum.uniq() end

put = fn id, attrs, sessions ->
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

  result =
    if is_nil(sessions), do: Import.put_listing(attrs), else: Import.put_listing(attrs, sessions)

  case result do
    {:ok, l} ->
      IO.puts("#{id}: #{length(l.occurrences)}")

    {:error, c} ->
      IO.inspect(c.errors)
      raise "failed #{id}"
  end
end

d = fn s -> String.split(s, ",") |> Enum.map(&Date.from_iso8601!/1) end
s = fn ds, st, et -> Enum.map(ds, &%{date: &1, start_time: st, end_time: et, timezone: tz}) end

put.(
  3,
  %{
    venue_id: 9,
    title: "Team HB Try-Outs",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "High-performance climbing team try-outs for athletes aged 8–18.",
    schedule_kind: "one_off",
    start_date: ~D[2026-08-14],
    end_date: ~D[2026-08-14],
    start_time: ~T[17:00:00],
    end_time: ~T[18:30:00],
    audience: ["youth"],
    ages: "8–18",
    confidence: "confirmed"
  },
  s.(d.("2026-08-14"), ~T[17:00:00], ~T[18:30:00])
)

put.(
  4,
  %{
    venue_id: 9,
    title: "The Breakfast Climb",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Breakfast social followed by climbing.",
    schedule_kind: "one_off",
    start_date: ~D[2026-07-25],
    end_date: ~D[2026-07-25],
    start_time: ~T[10:00:00],
    end_time: ~T[12:00:00],
    confidence: "confirmed"
  },
  s.(d.("2026-07-25"), ~T[10:00:00], ~T[12:00:00])
)

put.(
  18,
  %{
    venue_id: 30,
    title: "Bouldering 101 — Waterloo",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Two-hour beginner bouldering course for ages 16 and over.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    audience: ["adult"],
    ages: "16+",
    confidence: "tentative"
  },
  []
)

put.(
  27,
  %{
    venue_id: 10,
    title: "Youth Recreational Program — Fall 2026",
    kind: "class",
    cohorts: ["Fall 2026 timetable"],
    timezone: tz,
    summary:
      "Fall youth climbing programme with a published weekly timetable across progressive levels.",
    schedule_kind: "course",
    start_date: ~D[2026-09-11],
    end_date: ~D[2026-12-12],
    audience: ["youth"],
    ages: "8–18",
    confidence: "tentative",
    caveat:
      "The published timetable lists options rather than confirmed enrolment cohorts; end times are not printed and some dates are derived from term rules."
  },
  []
)

put.(
  29,
  %{
    venue_id: 10,
    title: "NextGen Program",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Assessment-based youth development pathway toward the competitive team.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    audience: ["youth"],
    ages: "5–9",
    confidence: "tentative"
  },
  []
)

put.(
  37,
  %{
    venue_id: 7,
    title: "Friendship Friday — Summer 2026",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Two-for-one admission social event for climbers aged 14 and over.",
    schedule_kind: "course",
    start_date: ~D[2026-06-26],
    end_date: ~D[2026-09-18],
    audience: ["adult"],
    ages: "14+",
    confidence: "confirmed",
    caveat: "Check-in windows are not organized event durations."
  },
  [%{date: ~D[2026-09-11], timezone: tz}, %{date: ~D[2026-09-18], timezone: tz}]
)

put.(
  45,
  %{
    venue_id: 17,
    title: "Friday Student Night",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Friday student climbing night for high-school, college and university students.",
    schedule_kind: "recurring",
    start_time: ~T[18:00:00],
    end_time: ~T[23:00:00],
    audience: ["adult"],
    confidence: "confirmed"
  },
  s.(
    d.("2026-09-11,2026-09-18,2026-09-25,2026-10-02,2026-10-09,2026-10-16,2026-10-23,2026-10-30"),
    ~T[18:00:00],
    ~T[23:00:00]
  )
)

put.(
  46,
  %{
    venue_id: 17,
    title: "Elimination Wednesday — August 26, 2026",
    kind: "competition",
    ocf: false,
    cohorts: [],
    timezone: tz,
    summary: "All-abilities elimination boulder competition.",
    schedule_kind: "one_off",
    start_date: ~D[2026-08-26],
    end_date: ~D[2026-08-26],
    start_time: ~T[19:00:00],
    end_time: ~T[21:00:00],
    confidence: "confirmed"
  },
  s.(d.("2026-08-26"), ~T[19:00:00], ~T[21:00:00])
)

put.(
  48,
  %{
    venue_id: 25,
    title: "Youth Programs — Spring 2027",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary:
      "Ten-week Spring 2027 youth climbing season for ages 4–17; individual cohort calendars are pending.",
    schedule_kind: "course",
    start_date: ~D[2027-04-05],
    end_date: ~D[2027-06-11],
    audience: ["youth"],
    ages: "4–17",
    confidence: "tentative",
    caveat: "Individual cohort dates and times are not published."
  },
  []
)

put.(
  49,
  %{
    venue_id: 25,
    title: "Start Climbing Club (Age 18+)",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Beginner-friendly adult recreational climbing club.",
    schedule_kind: "recurring",
    start_time: ~T[19:00:00],
    end_time: ~T[21:00:00],
    audience: ["adult"],
    ages: "18+",
    confidence: "confirmed"
  },
  s.(d.("2026-09-08,2026-09-15,2026-09-22,2026-09-29,2026-10-06"), ~T[19:00:00], ~T[21:00:00])
)

put.(
  54,
  %{
    venue_id: 29,
    title: "B/C-Class: Intro/Intermediate G0–G5 — October 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Four-week mixed beginner/intermediate bouldering class for G0–G5.",
    schedule_kind: "course",
    start_date: ~D[2026-10-01],
    end_date: ~D[2026-10-22],
    start_time: ~T[18:00:00],
    end_time: ~T[19:30:00],
    audience: ["adult"],
    confidence: "confirmed"
  },
  s.(d.("2026-10-01,2026-10-08,2026-10-15,2026-10-22"), ~T[18:00:00], ~T[19:30:00])
)

put.(
  58,
  %{
    venue_id: 29,
    title: "Challengers — Fall 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Invite-only youth climbing programme for experienced climbers aged 8–13.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    audience: ["youth"],
    ages: "8–13",
    confidence: "tentative",
    caveat: "Exact cohort dates and times are not published."
  },
  []
)

put.(
  136,
  %{
    venue_id: 25,
    title: "Fall Drink Smash! — Cafe Upstairs Gaming Night",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Upcoming Cafe Upstairs gaming event with a Super Smash Bros. tournament.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    confidence: "tentative",
    caveat: "Exact date and time are not published."
  },
  []
)

put.(
  159,
  %{
    venue_id: 42,
    title: "Lift With Confidence: Women's Edition",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Three-session strength coaching series for women.",
    schedule_kind: "course",
    start_date: ~D[2026-09-20],
    end_date: ~D[2026-10-04],
    start_time: ~T[09:00:00],
    end_time: ~T[11:00:00],
    audience: ["adult"],
    confidence: "confirmed",
    caveat:
      "An earlier page described four parts; the dated current announcement confirms three sessions."
  },
  s.(d.("2026-09-20,2026-09-27,2026-10-04"), ~T[09:00:00], ~T[11:00:00])
)

put.(
  230,
  %{
    venue_id: 4,
    title: "PNK — Picks No Kicking Dry Tooling",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Drytooling event at Basecamp Bloor West.",
    schedule_kind: "multi_day",
    start_date: ~D[2026-10-03],
    end_date: ~D[2026-10-04],
    confidence: "tentative",
    caveat: "Times and day format are unconfirmed."
  },
  [%{date: ~D[2026-10-03], timezone: tz}, %{date: ~D[2026-10-04], timezone: tz}]
)

put.(
  231,
  %{
    venue_id: 4,
    title: "Queer Climb Meetup — ongoing Bloor West series",
    kind: "social",
    cohorts: [],
    timezone: tz,
    summary: "Monthly queer climbers meetup with optional climbing groups.",
    schedule_kind: "recurring",
    start_time: ~T[17:00:00],
    end_time: ~T[19:00:00],
    confidence: "confirmed",
    caveat: "Series end is unknown."
  },
  s.(d.("2026-09-27,2026-10-25,2026-11-29,2026-12-27"), ~T[17:00:00], ~T[19:00:00])
)

put.(
  232,
  %{
    venue_id: 4,
    title: "Winter and Spring youth recreational programmes — 2027 schedule pending",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Announced winter and spring youth programmes with exact calendars pending.",
    schedule_kind: "unscheduled",
    start_date: nil,
    end_date: nil,
    start_time: nil,
    end_time: nil,
    audience: ["youth"],
    confidence: "tentative",
    caveat: "Exact dates and times are not published."
  },
  []
)

put.(
  253,
  %{
    venue_id: 4,
    title: "Neon Nights — Rope Edition",
    kind: "competition",
    ocf: false,
    cohorts: [],
    timezone: tz,
    summary: "Rope-focused climbing competition and games night.",
    schedule_kind: "one_off",
    start_date: ~D[2026-11-06],
    end_date: ~D[2026-11-06],
    start_time: ~T[17:00:00],
    end_time: ~T[23:00:00],
    confidence: "confirmed"
  },
  s.(d.("2026-11-06"), ~T[17:00:00], ~T[23:00:00])
)

put.(
  258,
  %{
    venue_id: 10,
    title: "Introductory Lesson — September 2026",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Ninety-minute introductory top-rope lessons for ages 13 and over.",
    schedule_kind: "course",
    start_date: ~D[2026-09-07],
    end_date: ~D[2026-09-13],
    audience: ["adult"],
    ages: "13+",
    confidence: "confirmed"
  },
  Enum.flat_map(
    [
      {d.("2026-09-07,2026-09-08,2026-09-09,2026-09-10"), ~T[12:00:00], ~T[13:30:00]},
      {d.("2026-09-07,2026-09-08,2026-09-09,2026-09-10"), ~T[14:00:00], ~T[15:30:00]},
      {d.("2026-09-07,2026-09-08,2026-09-09,2026-09-10"), ~T[16:00:00], ~T[17:30:00]},
      {d.("2026-09-07,2026-09-08,2026-09-09,2026-09-10"), ~T[18:00:00], ~T[19:30:00]},
      {d.("2026-09-11"), ~T[12:00:00], ~T[13:30:00]},
      {d.("2026-09-11"), ~T[14:00:00], ~T[15:30:00]},
      {d.("2026-09-12,2026-09-13"), ~T[10:00:00], ~T[11:30:00]},
      {d.("2026-09-12,2026-09-13"), ~T[12:00:00], ~T[13:30:00]},
      {d.("2026-09-12,2026-09-13"), ~T[14:00:00], ~T[15:30:00]},
      {d.("2026-09-12,2026-09-13"), ~T[16:00:00], ~T[17:30:00]}
    ],
    fn {ds, st, et} -> s.(ds, st, et) end
  )
)

put.(
  259,
  %{
    venue_id: 10,
    title: "Youth Competitive Team — 2026–2027 season training",
    kind: "class",
    cohorts: ["Baseline testing"],
    timezone: tz,
    summary:
      "Invitation-based youth competitive team programme with published baseline testing dates.",
    schedule_kind: "recurring",
    audience: ["youth"],
    ages: "9–19",
    confidence: "tentative",
    caveat:
      "Only baseline dates and area-use blocks are confirmed; full practice dates are unknown."
  },
  s.(d.("2026-09-08,2026-09-09,2026-09-10"), ~T[16:30:00], ~T[19:30:00])
)

put.(
  269,
  %{
    venue_id: 7,
    title: "Kinder Rok — Fall 2026",
    kind: "class",
    cohorts: ["Saturday", "Sunday"],
    timezone: tz,
    summary: "Thirteen-session climbing programme for ages 4–5 in Saturday and Sunday cohorts.",
    schedule_kind: "course",
    start_date: ~D[2026-09-19],
    end_date: ~D[2026-12-20],
    audience: ["youth"],
    ages: "4–5",
    confidence: "confirmed"
  },
  s.(
    d.(
      "2026-09-19,2026-09-26,2026-10-03,2026-10-17,2026-10-24,2026-10-31,2026-11-07,2026-11-14,2026-11-21,2026-11-28,2026-12-05,2026-12-12,2026-12-19"
    ),
    ~T[09:00:00],
    ~T[09:50:00]
  ) ++
    s.(
      d.(
        "2026-09-20,2026-09-27,2026-10-04,2026-10-18,2026-10-25,2026-11-01,2026-11-08,2026-11-15,2026-11-22,2026-11-29,2026-12-06,2026-12-13,2026-12-20"
      ),
      ~T[09:00:00],
      ~T[09:50:00]
    )
)

put.(
  270,
  %{
    venue_id: 7,
    title: "PA Day Camps — November 2026 and February 2027",
    kind: "camp",
    cohorts: [],
    timezone: tz,
    summary: "Two announced PA day climbing camps for ages 6–12.",
    schedule_kind: "multi_day",
    start_date: ~D[2026-11-20],
    end_date: ~D[2027-02-12],
    audience: ["youth"],
    ages: "6–12",
    confidence: "confirmed",
    caveat: "Camp times are not published."
  },
  [%{date: ~D[2026-11-20], timezone: tz}, %{date: ~D[2027-02-12], timezone: tz}]
)

put.(
  279,
  %{
    venue_id: 17,
    title: "Development Club",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Youth development coaching programme with Monday or Friday sessions advertised.",
    schedule_kind: "recurring",
    audience: ["youth"],
    confidence: "tentative",
    caveat: "Cohort dates and exact assigned weekday are unknown."
  },
  nil
)

put.(
  280,
  %{
    venue_id: 17,
    title: "Team Toprock — 2026/27 competitive youth programme",
    kind: "class",
    cohorts: [],
    timezone: tz,
    summary: "Competitive youth climbing training advertised twice weekly.",
    schedule_kind: "recurring",
    audience: ["youth"],
    confidence: "tentative",
    caveat: "Cohort dates and time-option assignment are unknown."
  },
  nil
)

put.(
  298,
  %{
    venue_id: 10,
    title: "OCF Lead - U17/ U19/ U21 /SR (SR SELECTION) — 2027-01-16",
    kind: "competition",
    ocf: true,
    cohorts: [],
    timezone: tz,
    summary: "OCF lead competition save-the-date.",
    schedule_kind: "one_off",
    start_date: ~D[2027-01-16],
    end_date: ~D[2027-01-16],
    confidence: "tentative"
  },
  [%{date: ~D[2027-01-16], timezone: tz}]
)

put.(
  310,
  %{
    venue_id: 29,
    title: "OCF Boulder U17/ U19/ U21 — 2027-02-06",
    kind: "competition",
    ocf: true,
    cohorts: [],
    timezone: tz,
    summary: "OCF boulder competition save-the-date.",
    schedule_kind: "multi_day",
    start_date: ~D[2027-02-06],
    end_date: ~D[2027-02-07],
    confidence: "tentative"
  },
  [%{date: ~D[2027-02-06], timezone: tz}, %{date: ~D[2027-02-07], timezone: tz}]
)
