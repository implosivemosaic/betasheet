# Architecture: components

## ClimbOntario (domain)

- `Catalogue` — facade. `search/1` takes a `Catalogue.Query` and returns `%{dated, ongoing, total}` over published listings only; `get_listing/1` by research event id (published only); `window/2` for the when-filter date ranges (weekend = Sat–Sun, week = seven dates, month = to month end). Date filters match confirmed `occurrences` for recurring listings and courses, never the bare term range. Offsite listings use their own coordinates or drop out of radius searches. A few hundred rows, filtered in memory.
- `Catalogue.Keyword` — pure normalized token/prefix/one-edit candidate matching, without relevance ranking, dependencies or external calls.
- `Catalogue.Query` — struct for what the visitor asked for; `from_params/2` and `to_params/1` keep filters in the URL. Type-checks inputs; malformed params fall back to defaults.
- `Catalogue.Listing` — destination schema/changeset: kinds plus explicit OCF flag, named cohort list, optional weekly/monthly pattern, bounds/default times, actual-location kind and offsite city, audience, one link, confidence, internal evidence and separate checked/substantive-update dates. Legacy prose label/schedule note are not presentation inputs. `Catalogue.Occurrence` holds confirmed local date/time/timezone and optional cohort/actual venue. `Catalogue.Venue` is one row per research gym; listing venue is the organizer, session venue can differ.
- `Catalogue.Import` — validated partial attrs update and optional full session replacement in one transaction; omission preserves sessions, explicit `[]` clears, invalid input rolls back. `publish/1` uses the same evidence gate. See `operations.md` for the exact contract.
- `Catalogue.Seed` + `Mix.Tasks.Catalogue.Seed` — one-time scaffolding: venues from research and geo, plus an unpublished skeleton per research event carrying only no-judgment facts. Never overwrites existing rows.
- `Catalogue.ResearchSource` — read-only adapter over the research SQLite.
- `Geo` — bundled lookups (`priv/geo`): resolve typed text to a point (valid postal FSA/full code first, then exact normalized reviewed place name; no prefix guessing), nearest place for device location, haversine distance. OpenCage source/precision metadata is bundled; `gym_metadata/1` controls safe approximate-point Map links. `Geo.Normalize` builds lookup keys.
- `Clock` — today's date in America/Toronto.
- `Interest` — one schema/write module for private-preview email+criteria+consent capture, gated by `:preview_interest`. Duplicate identical interest is a no-op. No delivery integration or read/export API.

## ClimbOntarioWeb

- `DiscoverLive` — `/`. Compact location/distance and three labelled native filter dialogs with Apply/Cancel, plus removable active filters (patch links), results in two sections. Search retains in-memory filtering/sorting; the LiveView renders only the first `20 * page` combined results, with explicit Load more and a shown/total label. Bounded URL depth survives detail/back navigation; filter links reset depth. `Locate` hook sends device coordinates; server maps them to the nearest place name.
- `ListingController` + `ListingHTML` — `/e/:slug`. Looks up by leading id, 301s stale slugs, 404s unknown or unpublished ids. Sets `meta` for Open Graph tags in the root layout.
- `ListingComponents` — `listing_card`, `kind_badge`, `chip`.
- `Format` — pure date/time/distance/label formatting.
- `Layouts` — root skeleton with meta tags; app chrome.
- Assets: `app.css` defines two daisyUI themes and the small motion vocabulary with a reduced-motion override. `app.js` holds the `Locate` and `CopyLink` hooks.
