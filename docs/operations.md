# Operations

## Development on the Dot box

```
source bin/ex-env.sh           # required: strips host env, puts real OTP first
mix setup                      # deps.get, ecto.setup, assets
mix catalogue.build            # rebuild venues + listings from the research DB
PORT=4200 mix phx.server
```

Supervised dev server (survives the chat):

```
lego work run --name climb-ontario-dev --cwd /data/workspace/climb-ontario -- bash -c 'source bin/ex-env.sh && export PORT=4200 && exec mix phx.server'
tailscale --socket=/data/run/tailscaled.sock serve --bg --https=8445 http://127.0.0.1:4200   # already configured, persistent
```

Stop: `lego work stop <id>` (find it with `lego work list`).

## Tests

`source bin/ex-env.sh && MIX_ENV=test mix test`. Tests use their own SQLite file and the Ecto sandbox.

## Refreshing data

1. Research workers update `ontario-gyms.sqlite` (outside this repo).
2. Optionally add or edit `priv/catalogue/editorial/*.json` entries for new event ids.
3. `mix catalogue.build`. It is idempotent; past events stay reachable by URL but drop out of results.

Gym coordinates come from `priv/geo/gyms.json`. New gyms need a row there (the `priv/geo` scripts geocode through `lego maps` and cache every response under `priv/geo/cache`).

## Configuration

- `RESEARCH_DB` — path to the research SQLite (default: the dot-files knowledge path).
- `PORT` — dev 4200. Port 4000 belongs to the host app.
- Production: standard Phoenix release env (`DATABASE_PATH`, `SECRET_KEY_BASE`, `PHX_HOST`).

## Known gaps

- No automatic restart of the dev server after a box restart.
- Link previews only unfurl once the site has a publicly reachable URL; tags are in place.
- No Open Graph image yet.
