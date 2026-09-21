# Follow-up to the bundle backfill, 2026-09-22: corrections found while reading
# each gym's page (quotes in tmp/bundles/batch-*.json, fetched copies in
# tmp/bundles/pages/). Listing-level ages that contradicted the gym, links that
# pointed at the wrong page, and two listings that were never bundles.
alias ClimbOntario.Catalogue
alias ClimbOntario.Catalogue.Import

fixes = [
  # ages: the gym's own wording
  {160, %{ages: "Ages 5–6"}, "RGP: 'Wee Rock (age 5-6) ... minimum age policy of 5 years old'"},
  {161, %{ages: "Ages 7–8"}, "RGP: 'You have selected the Alt. Rock (age 7-8) booking'"},
  {162, %{ages: "Ages 9–11"}, "RGP: 'You have selected the Pop Rock (age 9-11) booking'"},
  {42, %{ages: "Ages 7–10"}, "Mississauga RGP: 'Lil Rok (ages 7-10)'"},
  {30, %{ages: "Ages 5–6", link: "https://app.rockgympro.com/b/?bw=74b06684261a42a9af5420d46425fd3c",
         sources: ["https://app.rockgympro.com/b/?bw=74b06684261a42a9af5420d46425fd3c"]},
   "Markham RGP list: 'Blaze (5 - 6 year old) (Sept - Oct)'; old link was the Dragon offering"},
  {31, %{ages: "Ages 5–6"}, "RGP: 'Blaze Program Ages: 5 - 6'"},
  {264, %{ages: "Ages 7–9"}, "RGP: 'Dragon Program Ages: 7 - 9'"},
  {265, %{ages: "Ages 9–11"}, "RGP: 'Wyvern Program Ages: 9 - 11'"},
  {266, %{ages: "Ages 12–14"}, "RGP: 'Leviathan Program Ages: 12 - 14'"},
  {263, %{ages: "Ages 13–17"}, "RGP: 'Teen (13 - 17 Years Old) (Sept - Oct)'"},
  # links: the page that actually describes the programme
  {175, %{link: "https://climbmuskoka.com/youth-programs", sources: ["https://climbmuskoka.com/youth-programs"]},
   "old link was rockandropelondon.com, a different gym; Climb Muskoka page states Boulders 9-11 Tue/Thu 5:00-6:30"},
  {127, %{link: "https://www.rockandchalk.com/youth-lessons", sources: ["https://www.rockandchalk.com/youth-lessons"]},
   "old link was the home page"},
  {167, %{link: "https://www.rockandrope.com/spider-monkeys-and-chimps",
          sources: ["https://www.rockandrope.com/spider-monkeys-and-chimps", "https://app.rockgympro.com/b/?&bw=117e67769104495e9eaf87b46e7eaf0a"]},
   "old link /youth returns 404"},
  {112, %{sources: ["https://ajaxrockoasis.com/ajax-rock-oasis-kids-programs/", "https://app.rockgympro.com/b/widget/?a=offering&offering_guid=32141a8c43664316bafe8d7e86720a21&mode=p"]},
   "source RGP URL lacked /widget/ and returned an error page"},
  {52, %{link: "https://www.gravityhamilton.com/youthprograms", sources: ["https://www.gravityhamilton.com/youthprograms"]},
   "old link /climbing is a script shell with no programme text"},
  # not bundles: one team, one lesson at several times
  {121, %{ages: "Born 2013–2017", cohorts: [], bundled_by: nil, classes: []},
   "one team meeting Tue and Thu, one monthly fee; page: 'Youngest: born in 2017 · Oldest: born in 2013'"},
]

results =
  Enum.map(fixes, fn {id, attrs, why} ->
    case Import.put_listing(Map.put(attrs, :id, id)) do
      {:ok, _} -> {id, :ok, why}
      {:error, cs} -> {id, :error, inspect(Ecto.Changeset.traverse_errors(cs, fn {m, _} -> m end))}
    end
  end)

# 147: keep every session, drop the per-slot class names.
l = Catalogue.get_listing(147)
sessions =
  Enum.map(l.occurrences, fn o ->
    %{date: o.date, cohort: nil, start_time: o.start_time, end_time: o.end_time, timezone: o.timezone,
      location_kind: o.location_kind, venue_id: o.venue_id, offsite_name: o.offsite_name,
      offsite_address: o.offsite_address, offsite_city: o.offsite_city, offsite_lat: o.offsite_lat, offsite_lng: o.offsite_lng}
  end)

r147 =
  case Import.put_listing(%{id: 147, cohorts: [], bundled_by: nil, classes: []}, sessions) do
    {:ok, u} -> {147, :ok, "one 2-hour lesson at several slots; #{length(u.occurrences)} sessions kept"}
    {:error, cs} -> {147, :error, inspect(Ecto.Changeset.traverse_errors(cs, fn {m, _} -> m end))}
  end

for {id, status, note} <- results ++ [r147], do: IO.puts("#{status} #{id}: #{note}")

# Classes the gym does not list. Each checked on the gym's own page (and the
# booking widget, whose calendars had no bookable dates left to confirm from).
drops = [
  {23, "Monday", "joerockheads.com/schoolofrock: 'Rock Club ... Saturdays, 9:00-10:30am or Sundays, 9:30-11:00am'"},
  {68, "Wednesday", "junctionclimbing.com/youth-programs Junior Crushers: 'Fridays - 5-6pm Sundays - 9-10am Mondays - 6:15-7:15pm Tuesdays - 5-6pm NEW: Tuesdays - 8-9pm Thursdays - 5-6pm'"},
  {272, "Sunday 14:00", "RGP J Rok offering: 'Saturday & Sunday 12:15 p.m. - 2:15 p.m.'"}
]

for {id, name, why} <- drops do
  l = Catalogue.get_listing(id)
  keep = Enum.reject(l.occurrences, &(&1.cohort == name))

  sessions =
    Enum.map(keep, fn o ->
      %{date: o.date, cohort: o.cohort, start_time: o.start_time, end_time: o.end_time, timezone: o.timezone,
        location_kind: o.location_kind, venue_id: o.venue_id, offsite_name: o.offsite_name,
        offsite_address: o.offsite_address, offsite_city: o.offsite_city, offsite_lat: o.offsite_lat, offsite_lng: o.offsite_lng}
    end)

  attrs = %{id: id, cohorts: List.delete(l.cohorts, name), classes: Enum.reject(l.classes, &(&1.name == name)) |> Enum.map(&Map.take(&1, [:name, :ages, :level, :format]))}

  case Import.put_listing(attrs, sessions) do
    {:ok, u} -> IO.puts("ok #{id}: dropped '#{name}' (#{length(l.occurrences) - length(u.occurrences)} sessions); #{why}")
    {:error, cs} -> IO.puts("error #{id}: #{inspect(Ecto.Changeset.traverse_errors(cs, fn {m, _} -> m end))}")
  end
end
