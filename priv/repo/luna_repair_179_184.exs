alias ClimbOntario.Catalogue.Import

tz="America/Toronto"; put!=fn a,s->case Import.put_listing(a,s) do {:ok,l}->IO.puts("repaired #{l.id}: #{length(l.occurrences)} occurrences"); {:error,c}->IO.inspect(c);raise "repair failed" end end
o=fn d,s,e->%{date: d,start_time: s,end_time: e,timezone: tz} end
src=fn u->%{sources: u,checked_on: ~D[2026-09-06],published: false,confidence: "confirmed"} end
v=%{timezone: tz,venue_id: 48,location_kind: "venue",published: false}
for {id,title,kind,d,s,e,summary,url} <- [
 {179,"Ladies Night","social",~D[2026-09-08],~T[18:00:00],~T[21:00:00],"Welcoming climbing community night for women and gender-diverse climbers.","https://www.kitchenerclimbing.com/calendar"},
 {180,"Setting workshop — gym closed","class",~D[2026-09-12],~T[17:00:00],~T[20:00:00],"Hands-on route-setting workshop covering strategy, safety and route creation.","https://www.kitchenerclimbing.com/calendar"},
 {182,"Boulder League starts","competition",~D[2026-09-27],nil,nil,"Opening date for the KBC Boulder League.","https://www.kitchenerclimbing.com/calendar"},
 {183,"KBC Board Meeting — Online","social",~D[2026-09-30],~T[20:00:00],~T[21:00:00],"Public online cooperative board meeting.","https://www.kitchenerclimbing.com/calendar"},
 {184,"KBC's Anniversary","social",~D[2026-12-07],~T[17:00:00],~T[22:00:00],"KBC anniversary community celebration.","https://www.kitchenerclimbing.com/calendar"}
] do
 put!.(Map.merge(v,%{id: id,title: title,kind: kind,summary: summary,schedule_kind: "one_off",start_date: d,end_date: d,start_time: s,end_time: e,link: url,link_kind: "event"}|>Map.merge(src.([url]))),[o.(d,s,e)])
end
put!.(Map.merge(v,%{id: 181,title: "$10 Drop-In Week",kind: "social",summary: "Special drop-in climbing week at KBC.",schedule_kind: "multi_day",start_date: ~D[2026-09-13],end_date: ~D[2026-09-19],link: "https://www.kitchenerclimbing.com/calendar",link_kind: "event",schedule_note: "September 13–19 are campaign bounds, not daily opening hours."}|>Map.merge(src.(["https://www.kitchenerclimbing.com/calendar"]))),:preserve)
