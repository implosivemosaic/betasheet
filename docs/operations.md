# Operations

Running the app, deploying it, and changing production data. Research rules live in
`docs/research-rules.md`; the weekly run in `docs/weekly-refresh.md`. The full September deployment and
OpenCage history is archived in `betasheet-data/betasheet/research/history/operations-2026-09.md`.

## Production

| Resource | Value |
|---|---|
| Site | https://betasheet.ca (www and the old climb-ontario-keith.fly.dev redirect here) |
| Fly app / Machine | `climb-ontario-keith` / `874227b0321039`, region `yyz`, one shared CPU, 512 MB |
| Database | SQLite at `/data/catalogue.db` on volume `catalogue_data` (`vol_v8ek9mmjowkz535v`) |
| DNS / email | Cloudflare on Keith's personal account, records DNS-only; hello@betasheet.ca forwards to Keith |
| Fly token | `export FLY_API_TOKEN=$(../betasheet-data/betasheet/ops/fly-token.sh)` |

There is one Machine and one volume. Never scale it, never attach a second volume, never let a deploy
create a new database. Boot (`bin/release-start.sh`) refuses an absent or empty database, runs
migrations on the Machine, then starts the release.

## Running locally

See `AGENTS.md` for the clean-environment `mix` invocation. The local dev database
(`climb_ontario_dev.db`) should be a copy of production: `python3 research/run.py dev` after
`bin/pull-prod-db.sh`.

## Deploying code

```
export FLY_API_TOKEN=$(../betasheet-data/betasheet/ops/fly-token.sh)
flyctl deploy --app climb-ontario-keith --ha=false --image-label <short-name-YYYYMMDDHHMM>
```

Run the tests first. Image labels may contain only letters, digits, dots and dashes. After deploying,
check the change on https://betasheet.ca. A migration in the deploy runs on boot, so take a snapshot
before deploying one.

## Changing production data

1. Snapshot first: `bin/pull-prod-db.sh` (a consistent `VACUUM INTO` copy, into
   `betasheet-data/betasheet/snapshots/`).
2. Write the change through `Catalogue.Import.put_listing/2`. For research changes use
   `research/apply.sh dev`, then `research/apply.sh prod`. For a one-off correction, write a small
   script under `priv/repo/` with the evidence in a comment, run it on dev, then on production:

   ```
   code=$(base64 -w0 priv/repo/<script>.exs)
   flyctl agent stop
   flyctl machine exec 874227b0321039 \
     "/app/bin/climb_ontario rpc Code.eval_string(Base.decode64!(~S|$code|))" \
     -a climb-ontario-keith -t "$FLY_API_TOKEN"
   ```

3. Check the result on the live site, snapshot again, commit the script (code repo) and the snapshot
   (data repo).

Never copy a database file over production.

## Restoring production from a snapshot

Only if the live database is lost or corrupt, and with Keith's go-ahead. Stop the app Machine, start a
maintenance Machine on the `catalogue_data` volume running `sleep infinity`, upload the snapshot over
`flyctl ssh sftp`, check `pragma integrity_check`, rename it to `/data/catalogue.db`, destroy the
maintenance Machine, and redeploy with `--ha=false`.

## Stopping

`flyctl machine stop 874227b0321039 -a climb-ontario-keith` stops compute and keeps the volume, but any
request restarts it. For a lasting pause, first `flyctl machine update 874227b0321039 --autostart=false`.
Never destroy the volume.

## Page counter

Views go to the `page_views` table in the same database: no cookies, a daily-salted visitor hash, bots and
Fly health checks skipped. Report: `mix climb.stats [days]` locally, or the same summary over `rpc` on
production.

## Configuration

- `PHX_HOST`, `CONTACT_EMAIL`, `DATABASE_PATH` are set in `fly.toml`; `SECRET_KEY_BASE` is a Fly secret.
- `RESEARCH_DB` points `mix catalogue.seed` at the September research database (read-only). Not needed
  for the weekly refresh.
- Location data is the reviewed OpenCage bundle in `priv/geo/`, credited on `/location-data`. No
  geocoding calls happen at runtime.
- The email interest form exists but is switched off outside tests (`:preview_interest`). Keep it off.
