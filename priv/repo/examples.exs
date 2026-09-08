# Hand-converted example listings, one per shape, agreed in the room on 2026-09-08.
# Run: mix run priv/repo/examples.exs   (after mix catalogue.seed)
alias ClimbOntario.Catalogue.Import

put! = fn attrs, dates ->
  {:ok, _} = Import.put_listing(attrs, dates)
end

# Competition: Brawl in the Fall 2026, Grand River Rocks Waterloo (research event 17)
put!.(
  %{
    id: 17, venue_id: ClimbOntario.Repo.get_by!(ClimbOntario.Catalogue.Venue, source_gym_id: 30).id,
    title: "Brawl in the Fall 2026", kind: "competition", label: "Competition",
    summary: "Bouldering competition with scramble qualifiers in two waves and world-cup-style finals; top six per category advance. Cash and raffle prizes, food, beer and DJ.",
    schedule_kind: "one_off", start_date: ~D[2026-10-17], start_time: ~T[09:00:00],
    schedule_note: "Qualifiers 9 am-12 pm or 12:30-3:30 pm; finals 6 pm",
    price_state: nil, price_note: "Competitor fee not published; finals spectators free",
    audience: ["adult"], link: "https://grandriverrocks.com/waterloo/brawl-in-the-fall/", link_kind: "event",
    confidence: "confirmed", caveat: nil,
    sources: ["https://grandriverrocks.com/waterloo/brawl-in-the-fall/", "https://www.instagram.com/grr_wat/p/Dcwf54XJRf1/"],
    checked_on: ~D[2026-09-06], published: true
  },
  []
)

# Recurring meetup: Women's Bouldering Night, True North (research event 28)
put!.(
  %{
    id: 28, venue_id: ClimbOntario.Repo.get_by!(ClimbOntario.Catalogue.Venue, source_gym_id: 10).id,
    title: "Women's Bouldering Night", kind: "social", label: "Meetup",
    summary: "Monthly women's bouldering night with a reserved bouldering area and coaching tips from instructors. All skill levels welcome.",
    schedule_kind: "recurring", start_time: ~T[19:00:00], end_time: ~T[21:00:00],
    schedule_note: "Last Friday of the month, 7-9 pm",
    price_state: "members_free", price_note: "Members free; 2-for-1 day pass for non-members",
    audience: ["women"], link: "https://climber.hellocapitan.com/truenorthclimbing/schedule/events/157/", link_kind: "registration",
    confidence: "confirmed",
    sources: ["https://climber.hellocapitan.com/truenorthclimbing/schedule/events/157/", "https://www.instagram.com/truenorthclimbing/p/DU38v21jtaQ/"],
    checked_on: ~D[2026-09-06], published: true
  },
  [~D[2026-09-25], ~D[2026-10-30]]
)

# Course: Pebbles, Grand River Rocks Kitchener (research event 209)
put!.(
  %{
    id: 209, venue_id: ClimbOntario.Repo.get_by!(ClimbOntario.Catalogue.Venue, source_gym_id: 38).id,
    title: "Pebbles — Fall 2026", kind: "class", label: "Kids program",
    summary: "Movement, play and climbing for ages 2-5 with one participating adult per child. Six two-hour classes; preregistration required, no drop-ins.",
    schedule_kind: "course", start_date: ~D[2026-09-13], end_date: ~D[2026-10-18],
    start_time: ~T[08:00:00], end_time: ~T[10:00:00], schedule_note: "Six Sundays",
    price_state: "paid", price_note: "$150 + HST for six classes, harness included",
    audience: ["youth", "family"], ages: "Ages 2-5",
    link: "https://app.rockgympro.com/b/?bo=07fe4ef7bd87434a90ae44e654c9e3ee", link_kind: "registration",
    confidence: "confirmed",
    sources: ["https://app.rockgympro.com/b/?bo=07fe4ef7bd87434a90ae44e654c9e3ee", "https://grandriverrocks.com/kitchener/youth/pebbles/"],
    checked_on: ~D[2026-09-06], published: true
  },
  [~D[2026-09-13], ~D[2026-09-20], ~D[2026-09-27], ~D[2026-10-04], ~D[2026-10-11], ~D[2026-10-18]]
)

IO.puts("examples loaded")
