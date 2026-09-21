# Architecture: context and containers

The existing visual app at `/data/workspace/climb-ontario-visual` is the one canonical destination. Import/migration contract: `operations.md`.

## C1 — System context

**Visitors** (climbers and climbing parents on phones) come to find something to do near them and
share it. **Organizers** (gyms, the OCF) publish events on their own sites; we link out to them and
never take registration ourselves. **Researchers** (Dot's workers) read the research evidence and
write curated listings directly into the app database.

External systems:

- **Research database** (`ontario-gyms.sqlite`, maintained by Dot's research workers). Read-only input, used once by `mix catalogue.seed`.
- **OpenCage**, bundled from the September 17 accepted final review (996 selected points). No runtime provider calls or API keys. Source/precision/licence metadata is retained, with public credits at `/location-data`. Approximate gym Map links use organizer street-address queries; Google Maps is an outbound destination only, not a lookup input.
- **Organizer websites / booking systems** as the destination of every listing's link.

## C2 — Containers

| Container | Tech | Responsibility |
|---|---|---|
| Web app | Phoenix 1.8, LiveView, Bandit | Discovery screen (LiveView, URL-driven) and permanent event pages (plain controller HTML with Open Graph tags). Reads published listings only. |
| App database | SQLite (`climb_ontario_dev.db` / prod `DATABASE_PATH`) | `venues`, `listings`, `occurrences`. Listings and confirmed sessions are the destination format; additive columns capture cohorts, OCF, actual places and local times. Changesets enforce the import contract, with CHECK constraints for closed DB vocabularies. Written by researchers through `Catalogue.Import`. |
| Research database | SQLite, external | Evidence. Opened `mode=ro`, `query_only`, only by the seed. |
| Bundled data | `priv/geo/*.json` | Gym coordinates, Ontario FSA and place centroids. |

Key flow: research preserves evidence → `Catalogue.Import` writes reviewed, structured rows →
the web app displays published rows. Requests never touch the research file. A separately gated private-preview interest form writes only the app's `interests` table (email, criteria, consent timestamp); no email provider or delivery container exists.

Development stays on the Dot box/tailnet. A separate personal Fly test app is reachable at https://climb-ontario-keith.fly.dev (one shared CPU/512 MB Machine and a 1 GB SQLite volume in yyz). Boot migrations run on that attached Machine, never a separate release-command VM. Exact IDs, backup/bootstrap evidence and stop commands: `operations.md`. Limited public testing is explicitly authorized. Account entitlement is unknown; OpenCage's testing-only trial and production-plan policy remain documented limits, not a full legal-compliance claim.
