# Beta Sheet — agent notes

- Eligibility is recorded whole. If the organizer says "12+ or members of a competitive team", `ages` says both; never shorten an "or" to its first clause.

Mobile-first discovery site for Ontario climbing: competitions, socials, classes & clinics, camps.
Phoenix 1.8 + LiveView, SQLite via Ecto. Canonical app: `/data/workspace/climb-ontario-visual`. Read `docs/` first; `docs/operations.md` defines the exact import contract and backup-before-migration activation.

## Running on the Dot box

The host app exports its own Erlang/Phoenix environment. Always source the helper first:

```
source bin/ex-env.sh        # real OTP on PATH, host env stripped, MIX_ENV=dev
mix setup                   # deps, db, assets
mix catalogue.seed          # venues + one UNPUBLISHED skeleton per research event (idempotent)
PORT=4200 mix phx.server    # 4000 belongs to the host app
```

Tests: `source bin/ex-env.sh && MIX_ENV=test mix test`.

## Hard rules

- The research database (`RESEARCH_DB`, default under `/data/workspace/dot-files/knowledge/ontario-gyms/`) is read-only input. Never write to it from this repo.
- The app database is the destination format. Listing/occurrence changesets plus additive migration define the spec; enums have CHECK constraints. Named cohorts share one listing (two or more make a bundle, which records `bundled_by` and per-class `classes`; see docs/operations.md), occurrences hold confirmed local times and actual venues. Code never parses prose to guess kind, audience or schedule. Price, rules and booking conditions are not in the schema; they stay on the organizer's page.
- Curated rows are written through `Catalogue.Import.put_listing/2` (one transaction for listing and confirmed sessions). Omitted sessions preserve; explicit `[]` clears. Code owns badges/schedule/location lines; legacy prose fields are not UI inputs. Researchers do the judgment; the app validates and loads.
- `published` is false until every judgment column is filled. Search and event pages read published rows only.
- `listings.id` is the research event id and leads every public URL. Old slugs redirect.
- No accounts, calendar sync or registration availability tracking. Dedicated Fly HTTPS test deployment is authorized; see `docs/operations.md` for exact app/Machine/volume IDs. Limited public testing with the reviewed OpenCage bundle is authorized. Actual account entitlement is unknown; public production/promotion requires resolving the documented plan/provenance limits. See `/location-data` and the deployment report linked from operations.

## Where things live

- `lib/climb_ontario/catalogue/`: `listing.ex` (schema + changeset, the spec), `occurrence.ex` (confirmed dates), `import.ex` (validating write path), `seed.ex` (one-time skeletons from research), `research_source.ex` (read-only adapter), `query.ex` (URL filters).
- `priv/repo/examples.exs`: the three hand-converted examples agreed in the room; `mix run priv/repo/examples.exs`.
- `priv/catalogue/editorial/*.json`: earlier agent-written summaries, kept as reference for converters. Not loaded by the app.
- `lib/climb_ontario/geo.ex` bundled place/postal lookups, no network.
- `lib/climb_ontario_web/live/discover_live.ex` the discovery screen; `controllers/listing_controller.ex` the permanent event page.
- Tests sit beside the code they cover under `test/`, mirroring `lib/`.
