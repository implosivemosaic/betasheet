# Architecture: components

## ClimbOntario (domain)

- `Catalogue` — facade. `search/1` takes a `Catalogue.Query` and returns `%{dated, ongoing, total}`; `get_listing/1` by research event id; `window/2` for the when-filter date ranges. The listed catalogue is a few hundred rows, so search loads it and filters in memory.
- `Catalogue.Query` — struct for what the visitor asked for; `from_params/2` and `to_params/1` keep filters in the URL.
- `Catalogue.Listing`, `Catalogue.Venue` — Ecto schemas. Listing kinds: competition, social, class, camp. Schedule kinds: one_off, multi_day, course, recurring, unscheduled.
- `Catalogue.Mapper` — pure translation from a research event row to listing attrs: kind, subkind, audience, skill, schedule kind, confidence, registration state, venue note, organizer link, listed flag.
- `Catalogue.Text` — pure formatters that repair space-collapsed research prose, build summaries, slugs, short prices.
- `Catalogue.ResearchSource` — read-only adapter over the research SQLite.
- `Catalogue.Builder` + `Mix.Tasks.Catalogue.Build` — idempotent ETL; upserts by source ids, removes listings whose source vanished.
- `Geo` — bundled lookups (`priv/geo`): resolve typed text to a point (postal FSA first, then exact place, then prefix), nearest place for device location, haversine distance. `Geo.Normalize` builds lookup keys.
- `Clock` — today's date in America/Toronto.

## ClimbOntarioWeb

- `DiscoverLive` — `/`. Location form, when/kind/audience chips (patch links), results in two sections. `Locate` hook sends device coordinates; server maps them to the nearest place name.
- `ListingController` + `ListingHTML` — `/e/:slug`. Looks up by leading id, 301s stale slugs, 404s unknown ids. Sets `meta` for Open Graph tags in the root layout.
- `ListingComponents` — `listing_card`, `kind_badge`, `chip`.
- `Format` — pure date/time/distance/label formatting.
- `Layouts` — root skeleton with meta tags; app chrome (wordmark, footer disclaimer).
- Assets: `app.css` defines two daisyUI themes (`chalk` light, `granite` dark) and the small motion vocabulary (`card-lift`, `chip`, `fade-up`, `pop`) with a reduced-motion override. `app.js` holds the `Locate` and `CopyLink` hooks.
