# Climb Ontario — agent notes

Mobile-first discovery site for Ontario climbing: competitions, socials, classes & clinics, camps.
Phoenix 1.8 + LiveView, SQLite via Ecto. Read `docs/` first.

## Running on the Dot box

The host app exports its own Erlang/Phoenix environment. Always source the helper first:

```
source bin/ex-env.sh        # real OTP on PATH, host env stripped, MIX_ENV=dev
mix setup                   # deps, db, assets
mix catalogue.build         # research DB (read-only) -> priv catalogue tables
PORT=4200 mix phx.server    # 4000 belongs to the host app
```

Tests: `source bin/ex-env.sh && MIX_ENV=test mix test`.

## Hard rules

- The research database (`RESEARCH_DB`, default under `/data/workspace/dot-files/knowledge/ontario-gyms/`) is read-only input. Never write to it from this repo.
- Public copy comes from `priv/catalogue/editorial/*.json`, keyed by research event id. Edit those files to change what visitors read; never patch the research DB.
- Slugs are `<research event id>-<title>`; the leading id is the permanent key. Old slugs redirect.
- No accounts, no calendar sync, no public deploy in this slice.

## Where things live

- `lib/climb_ontario/catalogue/` data layer: `mapper.ex` (pure research row -> listing), `text.ex` (pure formatters), `builder.ex` (ETL), `research_source.ex` (read-only adapter).
- `lib/climb_ontario/geo.ex` bundled place/postal lookups, no network.
- `lib/climb_ontario_web/live/discover_live.ex` the discovery screen; `controllers/listing_controller.ex` the permanent event page.
- Tests sit beside the code they cover under `test/`, mirroring `lib/`.
