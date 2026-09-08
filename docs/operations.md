# Operations

## Development on the Dot box

```
source bin/ex-env.sh           # required: strips host env, puts real OTP first
mix setup                      # deps.get, ecto.setup, assets
mix catalogue.seed             # venues + unpublished skeletons from the research DB (idempotent, never overwrites)
mix run priv/repo/examples.exs # the three agreed example listings, published
PORT=4200 mix phx.server
```

Supervised dev server (survives the chat, not a box restart):

```
lego work run --name climb-ontario-dev --cwd /data/workspace/climb-ontario -- bash -c 'source bin/ex-env.sh && export PORT=4200 && exec mix phx.server'
tailscale --socket=/data/run/tailscaled.sock serve --bg --https=8445 http://127.0.0.1:4200   # already configured, persistent
```

Stop: `lego work stop <full work id>` (find it with `lego work list`).

## Tests

`source bin/ex-env.sh && MIX_ENV=test mix test`. Tests use their own SQLite file and the Ecto sandbox.

## Converting and adding listings

Researchers write rows with `ClimbOntario.Catalogue.Import.put_listing(attrs, dates)` from a
mix script (see `priv/repo/examples.exs`). `attrs` are the `listings` columns; `dates` are the
confirmed occurrence dates for recurring listings and courses. Column meanings and allowed values
are commented in `priv/repo/migrations/20260908000000_create_catalogue.exs`.

- A row inserts unpublished; set `published: true` (or call `Import.publish/1`) once kind, label, summary, schedule_kind, confidence, link and link_kind are filled. The changeset and a CHECK constraint both refuse an incomplete published row.
- `caveat` is for uncertainty in our displayed date, time or place only; gym closures, door times and other logistics stay on the organizer's page.
- Invalid enum values, missing dates for a dated shape, or an offsite name without coordinates are rejected; nothing is guessed.
- Unpublished rows are invisible to search and return 404 on their page.

New gyms need a row in `priv/geo/gyms.json` for coordinates.

## Configuration

- `RESEARCH_DB` — path to the research SQLite (default: the dot-files knowledge path). Seed only.
- `PORT` — dev 4200. Port 4000 belongs to the host app.
- Production: standard Phoenix release env (`DATABASE_PATH`, `SECRET_KEY_BASE`, `PHX_HOST`).

## Known gaps

- No automatic restart of the dev server after a box restart.
- Link previews only unfurl once the site has a publicly reachable URL; tags are in place.
- No Open Graph image yet.
- Bundled geo data is Google-derived and should be replaced with openly licensed sources before public launch.
