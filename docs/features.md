# Features

## Discovery (`/`)

- Location prompt: city, town or postal code, with typeahead of Ontario places. Not a gate; the page shows upcoming listings province-wide until a place is entered.
- "Use my location" maps device coordinates to the nearest known place.
- Radius 40 km by default; one-tap widen to 100 km; empty state offers 150 km.
- Filters, all in the URL: kind (competitions, socials & meetups, classes & clinics, camps), when (anytime, this weekend, next 7 days, this month), who (collapsed: kids & youth, adults, families, adaptive).
- Results: "Coming up" sorted by date (kinds interleaved when no filter or place is set), then "Ongoing & recurring". Date filters match confirmed occurrence dates only. Programs with no posted schedule are hidden by default with a one-tap reveal.
- Cards show kind badge, title, venue and distance, when line plus schedule note, summary, ages, price (only when published and clear), Tentative tag, Today/Tomorrow/This weekend hints.

## Event page (`/e/<id>-<slug>`)

- Permanent URL keyed by research event id; stale slugs redirect; unpublished rows 404.
- Title, venue and city with map link; one block for when, price, who; summary; a caveat only when our own date, time or place is uncertain.
- One prominent link labelled by what it is: "Register with organizer", "View official event", or "Gym website". "Copy link" copies the URL (native share sheet on phones).
- Open Graph and Twitter meta tags for link previews. Past listings show a notice.
- Sources and the checked date in the footer.

## Data

- 54 venues. 311 research events seeded as unpublished skeletons; 3 hand-converted examples published so far. Conversion of the rest is a researcher task.
- Bundled geo: 54 gym coordinates, 526 Ontario FSAs, 427 place names.
