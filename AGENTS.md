# Beta Sheet — agent notes

Beta Sheet (https://betasheet.ca) is Keith's personal project: a mobile-first guide to indoor climbing
competitions, socials, classes and camps in Ontario. Discovery only: every listing links to the
organizer, who handles booking. Phoenix 1.8 + LiveView, SQLite via Ecto, one Fly Machine.

## Read in this order

1. This file.
2. `docs/research-rules.md` — what a listing is and how to record one. Every research task follows it.
3. `docs/weekly-refresh.md` — the weekly run that finds new and changed events, step by step.
4. `docs/operations.md` — running the app locally, deploying, changing production data, backups.

`docs/features.md` and `docs/architecture-*.md` describe the app itself.

## Where things live

| What | Where |
|---|---|
| Code (public) | `/data/workspace/repos/climb-ontario`, github.com/implosivemosaic/betasheet |
| Data and research (private) | `/data/workspace/repos/betasheet-data`, github.com/implosivemosaic/betasheet-data, folder `betasheet/` |
| Source list | `betasheet-data/betasheet/sources.json` |
| Weekly runs | `betasheet-data/betasheet/runs/<date>/` |
| Production database snapshots | `betasheet-data/betasheet/snapshots/` |
| Production | Fly app `climb-ontario-keith`, Machine `874227b0321039`, database `/data/catalogue.db` |
| Research tools | `research/` in this repo |
| September research archive | `betasheet-data/betasheet/research/ontario-gyms/` (read-only history) |

## Hard rules

- Production is the source of truth for listings. Change it only through `Catalogue.Import.put_listing/2`,
  after a fresh snapshot (`bin/pull-prod-db.sh`), and never by copying a database over it.
- Nothing goes live without Keith's approval. Research proposes; Keith approves; then it is applied.
- Never invent facts. A date, time, age, place or class comes from a page you actually read, with a quote.
  Unknown stays empty.
- Keith's desktop browser (`lego browser`) is for Instagram and Facebook only, because it is logged in.
  Everything else is read from this box.
- Secrets never go in a room, a commit or a file in git. The Fly token comes from
  `betasheet-data/betasheet/ops/fly-token.sh`.

## Git

- Author and committer are Keith: `Keith Hassen <61853129+implosivemosaic@users.noreply.github.com>`.
  Both repos have this in their local config; check before committing.
- One-line commit messages under 100 characters, no prefixes like `feat:`. Commit straight to `main`.

## Running on the Dot box

The box's own Phoenix app leaks environment into shells, so run mix in a clean environment:

```
cd /data/workspace/repos/climb-ontario
env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root TERM=dumb \
  MIX_ENV=test LANG=C.UTF-8 ELIXIR_ERL_OPTIONS=+fnu mix test
```

Port 4000 belongs to the box; use `PORT=4200` for a local server. `bin/ex-env.sh` does the same
cleanup when sourced into an interactive shell.

## Known box quirks

- If `flyctl` says "You must be authenticated" with a token that works, a hung local agent is
  swallowing calls: `flyctl agent stop`, then pass the token with `-t`.
- `flyctl machine exec` splits its command on spaces. Send Elixir base64-encoded inside `~S|…|`,
  as `research/apply.sh` and `bin/pull-prod-db.sh` do.
- When replacing a local SQLite file, delete its `-wal` and `-shm` files too, or old rows come back.
