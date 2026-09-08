# Architecture: context and containers

## C1 — System context

**Visitors** (climbers and climbing parents on phones) come to find something to do near them and
share it. **Organizers** (gyms, the OCF) publish events on their own sites; we link out to them and
never take registration ourselves.

External systems:

- **Research database** (`ontario-gyms.sqlite`, maintained by Dot's research workers). Read-only input.
- **Google Maps Geocoding**, used once at build time through `lego maps` to produce the bundled geo tables. Not called at runtime.
- **Organizer websites / booking systems** as the destination of every "Details & registration" link.

## C2 — Containers

| Container | Tech | Responsibility |
|---|---|---|
| Web app | Phoenix 1.8, LiveView, Bandit | Discovery screen (LiveView, URL-driven) and permanent event pages (plain controller HTML with Open Graph tags). |
| App database | SQLite (`climb_ontario_dev.db` / prod `DATABASE_PATH`) | `venues` and `listings`, the curated public catalogue. Rebuilt by `mix catalogue.build`. |
| Research database | SQLite, external | Source of truth for gyms, events, sources. Opened `mode=ro`, `query_only`. |
| Bundled data | `priv/geo/*.json`, `priv/catalogue/editorial/*.json` | Gym coordinates, Ontario FSA and place centroids, hand-written summaries. Compiled in or read at build time. |

Key flow: `mix catalogue.build` reads research rows, applies the pure `Mapper`, merges the editorial
overlay, and upserts into the app database. Requests never touch the research file.

Deployment topology today: dev server on the Dot box, port 4200, exposed to Keith's tailnet by
Tailscale Serve on 8445. No public deploy yet; the app is release-ready (SQLite file + `DATABASE_PATH`).
