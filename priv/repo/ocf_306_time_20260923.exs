# Listing 306: the OCF page states a start time the record lacked.
# Source: https://www.climbontario.ca/events/ocf-u11-u13-u15-tope-rope — "Sunday, October 25, 2026 9:00 a.m."
# (The page's 10:00 p.m. end looks like a placeholder and is not recorded.)
l = ClimbOntario.Catalogue.get_listing(306)
[o] = l.occurrences
sessions = [%{date: o.date, cohort: o.cohort, start_time: ~T[09:00:00], end_time: nil, timezone: o.timezone, location_kind: o.location_kind, venue_id: o.venue_id}]
case ClimbOntario.Catalogue.Import.put_listing(%{id: 306, start_time: ~T[09:00:00]}, sessions) do
  {:ok, u} -> IO.puts("ok 306: #{hd(u.occurrences).date} #{hd(u.occurrences).start_time} exportable=#{ClimbOntarioWeb.SessionCalendar.exportable?(hd(u.occurrences))}")
  {:error, cs} -> IO.inspect(cs.errors, label: "error 306")
end
