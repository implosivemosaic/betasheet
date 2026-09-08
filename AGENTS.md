# Climb Ontario — agent notes

Mobile-first discovery site for Ontario climbing: competitions, socials, classes & clinics, camps.
Phoenix 1.8 + LiveView, SQLite via Ecto. Read `docs/` first.

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
- The app database is the destination format. `listings` columns are the spec; enums are CHECK constraints; a row that doesn't fit doesn't insert. Code never parses prose to guess kind, price, audience or schedule.
- Curated rows are written through `Catalogue.Import.put_listing/2` (one transaction for the listing and its confirmed dates). Researchers do the judgment; the app validates and loads.
- `published` is false until every judgment column is filled. Search and event pages read published rows only.
- `listings.id` is the research event id and leads every public URL. Old slugs redirect.
- No accounts, no calendar sync, no registration availability tracking, no public deploy in this slice.

## Where things live

- `lib/climb_ontario/catalogue/`: `listing.ex` (schema + changeset, the spec), `occurrence.ex` (confirmed dates), `import.ex` (validating write path), `seed.ex` (one-time skeletons from research), `research_source.ex` (read-only adapter), `query.ex` (URL filters).
- `priv/repo/examples.exs`: the three hand-converted examples agreed in the room; `mix run priv/repo/examples.exs`.
- `priv/catalogue/editorial/*.json`: earlier agent-written summaries, kept as reference for converters. Not loaded by the app.
- `lib/climb_ontario/geo.ex` bundled place/postal lookups, no network.
- `lib/climb_ontario_web/live/discover_live.ex` the discovery screen; `controllers/listing_controller.ex` the permanent event page.
- Tests sit beside the code they cover under `test/`, mirroring `lib/`.
