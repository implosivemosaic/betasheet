# Architecture: context and containers

## C1 — System context

**Visitors** (climbers and climbing parents on phones) come to find something to do near them and
share it. **Organizers** (gyms, the OCF) publish events on their own sites; we link out to them and
never take registration ourselves. **Researchers** (Dot's workers) read the research evidence and
write curated listings directly into the app database.

External systems:

- **Research database** (`ontario-gyms.sqlite`, maintained by Dot's research workers). Read-only input, used once by `mix catalogue.seed`.
- **Google Maps Geocoding**, used once through `lego maps` to produce the bundled geo tables. Not called at runtime. Its caching terms don't fit a permanent bundled lookup; replacing the bundled data with openly licensed sources is on the pre-launch list.
- **Organizer websites / booking systems** as the destination of every listing's link.

## C2 — Containers

| Container | Tech | Responsibility |
|---|---|---|
| Web app | Phoenix 1.8, LiveView, Bandit | Discovery screen (LiveView, URL-driven) and permanent event pages (plain controller HTML with Open Graph tags). Reads published listings only. |
| App database | SQLite (`climb_ontario_dev.db` / prod `DATABASE_PATH`) | `venues`, `listings`, `occurrences`. The listings schema is the agreed destination format; CHECK constraints enforce its vocabularies. Written by researchers through `Catalogue.Import`. |
| Research database | SQLite, external | Evidence. Opened `mode=ro`, `query_only`, only by the seed. |
| Bundled data | `priv/geo/*.json` | Gym coordinates, Ontario FSA and place centroids. |

Key flow: research preserves evidence → `Catalogue.Import` writes reviewed, structured rows →
the web app displays published rows. Requests never touch the research file.

Deployment topology today: dev server on the Dot box, port 4200, exposed to Keith's tailnet by
Tailscale Serve on 8445. No public deploy yet.
