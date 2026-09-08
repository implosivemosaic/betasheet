# Architecture: components

## ClimbOntario (domain)

- `Catalogue` — facade. `search/1` takes a `Catalogue.Query` and returns `%{dated, ongoing, total}` over published listings only; `get_listing/1` by research event id (published only); `window/2` for the when-filter date ranges (weekend = Sat–Sun, week = seven dates, month = to month end). Date filters match confirmed `occurrences` for recurring listings and courses, never the bare term range. Offsite listings use their own coordinates or drop out of radius searches. A few hundred rows, filtered in memory.
- `Catalogue.Query` — struct for what the visitor asked for; `from_params/2` and `to_params/1` keep filters in the URL. Type-checks inputs; malformed params fall back to defaults.
- `Catalogue.Listing` — Ecto schema and changeset. This is the destination format: kind, label, summary, schedule shape and dates, audience and ages, one link and its kind, optional offsite venue, confidence, caveat, sources, checked date, published. Closed vocabularies are also CHECK constraints in the migration. `Catalogue.Occurrence` holds confirmed dates. `Catalogue.Venue` is one row per research gym.
- `Catalogue.Import` — the only write path: `put_listing/2` validates and writes a listing plus its occurrence dates in one transaction; `publish/1` flips a complete row live.
- `Catalogue.Seed` + `Mix.Tasks.Catalogue.Seed` — one-time scaffolding: venues from research and geo, plus an unpublished skeleton per research event carrying only no-judgment facts. Never overwrites existing rows.
- `Catalogue.ResearchSource` — read-only adapter over the research SQLite.
- `Geo` — bundled lookups (`priv/geo`): resolve typed text to a point (postal FSA first, then exact place, then prefix), nearest place for device location, haversine distance. `Geo.Normalize` builds lookup keys.
- `Clock` — today's date in America/Toronto.

## ClimbOntarioWeb

- `DiscoverLive` — `/`. Location form, kind/when chips and a collapsed "who it's for" (patch links), results in two sections. `Locate` hook sends device coordinates; server maps them to the nearest place name.
- `ListingController` + `ListingHTML` — `/e/:slug`. Looks up by leading id, 301s stale slugs, 404s unknown or unpublished ids. Sets `meta` for Open Graph tags in the root layout.
- `ListingComponents` — `listing_card`, `kind_badge`, `chip`.
- `Format` — pure date/time/distance/label formatting.
- `Layouts` — root skeleton with meta tags; app chrome.
- Assets: `app.css` defines two daisyUI themes and the small motion vocabulary with a reduced-motion override. `app.js` holds the `Locate` and `CopyLink` hooks.
