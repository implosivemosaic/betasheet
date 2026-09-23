# Operations

## Canonical app and safe activation

`/data/workspace/climb-ontario-visual` is the canonical destination and visual app. Research SQLite is read-only evidence; requests and imports never write it. Work only in this app. No bulk conversion, paid APIs, accounts or subscription features. Dedicated Fly HTTPS reachability testing is now authorized below.

```
cd /data/workspace/climb-ontario-visual
source bin/ex-env.sh
MIX_ENV=test mix test          # migrates only the separate test database
```

The additive `20260917000000_structure_listing_sessions.exs` migration leaves research IDs, publication flags, evidence and timestamps intact. It classifies reviewed example 17 as non-OCF, preserves legacy offsite locations and snapshots existing occurrence times from listing defaults. Legacy timezone and substantive-update date remain unknown rather than invented. The original migration stays applied and unchanged.

Before applying the migration to dev, stop the dev server and make a SQLite backup (includes committed WAL contents):

```
python3 - <<'PY'
import sqlite3, datetime
path = 'climb_ontario_dev.db'
backup = path + '.before-sessions-' + datetime.datetime.now().strftime('%Y%m%d%H%M%S') + '.bak'
with sqlite3.connect('file:' + path + '?mode=ro', uri=True) as src, sqlite3.connect(backup) as dst:
    src.backup(dst)
print(backup)
PY
mix ecto.migrate
PORT=4200 mix phx.server
```

Stop/start the existing supervised server deliberately after review; inspect `lego work list` for its full ID and current port. No server activation is required to test these changes. Never use `mix setup` as a migration shortcut on existing data. Verify the current 302 published / 9 held counts and unchanged source/occurrence counts before and after activation. Do not run seed, example refresh or import scripts for interest activation.

## Preview interest capture: activation after coordinator review

The additive `20260918000000_create_interests.exs` creates only `interests`; no catalogue/research data is changed. The coordinator already backed up and applied it during preview recovery. Dev capture remains disabled; tests enable it. Do not enable outside the private tailnet preview.

After review, the coordinator should:

1. Record counts without reading email addresses: `SELECT published, count(*) FROM listings GROUP BY published; SELECT count(*) FROM occurrences; SELECT sum(json_array_length(sources)) FROM listings;` (SQLite read-only connection).
2. Stop the existing supervised preview (currently port 4201); take the SQLite backup above, using a new filename. Run `source bin/ex-env.sh && MIX_ENV=dev mix ecto.migrate` from this canonical app (already applied migrations are no-ops).
3. For the private preview only, enable `:preview_interest` for dev in `config/config.exs` (currently test-only). Restart the same supervised server with `PORT=4201`; configuration changes require restart. No public exposure.
4. Verify home, OCF filter and detail HTTP 200, unchanged catalogue/source counts, and the interest form. Re-disable the flag and restart to withdraw capture; existing private interest rows remain stored.

`Interest.save/1` stores normalized email, editable location/radius/kinds/audience and server-generated UTC consent time. An unchecked consent or invalid input is rejected. Identical normalized email+criteria submissions are a no-op preserving original consent time; different criteria create a separate interest, not a subscription update. Blank location means Ontario; empty kind/audience sets mean all. Date-window filters are intentionally not saved. No emails, providers, accounts, delivery jobs or subscription state exist.

Emails stay in the private app SQLite, including its protected backups. There is no list/export endpoint. Interest inserts disable SQL parameter logging, schema inspection redacts email, Phoenix filters interest/email parameters, and supported LiveView-level logging disables event parameter logs. CSRF protections remain enabled. Do not inspect/log/export rows in public tools or room messages. The form and confirmation explicitly say interest only and no emails sent; it makes no future delivery promise.

Detail pages show structured schedule summaries and a collapsed confirmed-sessions disclosure. Shared venue/address is shown in Where; shared timezone is shown once above the sessions. Differing session locations/timezones remain visible.

## Exact importer contract

`ClimbOntario.Catalogue.Import.put_listing(attrs, sessions)` returns `{:ok, listing}` (preloaded actual venues/sessions) or `{:error, changeset}`. Validation and all writes run in one transaction; failed listing/session inserts roll back the entire update. Errors may concern a listing or occurrence; SQLite integrity failures without a constraint name are attached to `:base`.

- `attrs` is an atom-keyed or string-keyed map of listing columns. `id` is the stable research event ID. Existing rows receive **partial updates**: omitted fields preserve values. New rows require `id`, organizing `venue_id`, `title`, `checked_on`. No new public IDs are invented during conversion.
- **Omit the second argument to preserve occurrences.** Supply a list to replace the entire set, including `[]` to clear it. Each item is a Date, ISO date string, or session map. Malformed sessions, duplicates, backwards dates/times, out-of-bound occurrences and invalid HTTP(S) URLs fail without changing either table. Sessions are confirmed evidence, never expanded from a pattern.
- `publish(id)` uses the same transaction and validation. Publishing requires kind, summary, schedule kind, confidence, link, link kind and at least one valid HTTP(S) evidence URL in `sources`. Drafts may keep an empty source list. Competitions require explicit `ocf: true` or `false`; other kinds leave `ocf` null. Discovery offers OCF, other competitions, social, class, camp. Legacy `label` and `schedule_note` are ignored by presentation; code owns badges/date/time/location wording. `label` is filled by code for the original DB constraint.
- `cohorts: ["Ages 6–8", "Ages 9–12"]` names the classes inside **one listing**. Session `cohort` must match one of these names (null = unnamed session). Classes without confirmed sessions display dates/times as unknown. No separate per-class product, booking or availability model.
- **Bundles.** Two or more named cohorts make a bundle, and a bundle must say what its classes are split by: `bundled_by` is `age`, `level`, `format`, `day` or `mixed`. Each class then carries the fact that sets it apart in `classes: [%{name: "Ages 6–8", ages: "6–8"}, ...]` (fields `name`, `ages`, `level`, `format`; `name` must be one of `cohorts`). `age` requires `ages` on every class, `level` requires `level`, `format` requires `format`, `mixed` requires at least one of them; `day` bundles differ only by weekday or time and need no `classes` entries. Day and time are never written into a class: they come from its sessions. Required for every new bundle and whenever a bundle's cohorts change; bundles written before this rule pass until then and are being backfilled by inspection of their source pages.
- **Naming a class.** The name states what distinguishes the class, and nothing else: the age band ("Ages 6–8"), the level or stream ("Level 2", "Development Team"), or the format ("Adult/Child"), joined with " · " when more than one applies. Never put the weekday or time in the name; the site derives "Monday class" and the times from sessions. The one exception is uniqueness: when two classes share the same facts and differ only by day, append " — " and the weekday (plus start time if still ambiguous), as in "Ages 8–10 — Saturday". For a `day` bundle the name is the weekday(s) alone ("Monday", "Tue/Thu"), or weekday plus start time when the same day runs twice ("Saturday 11:00").
- `complete_cohorts: []` (default) means completeness is unknown. A reviewer may assert a finite course group's entire ordered schedule is recorded using its exact cohort name, or the reserved marker `"__unnamed__"` for sessions with null cohort. Named cohorts cannot use that reserved name. Markers must be unique, refer to existing groups, and each marked group must contain confirmed sessions. Only courses may be marked. This assertion enables #N of total within the selected cohort's full session sequence, including past/filter-excluded dates; bounds, patterns and sparse samples never establish completeness. Omitted markers preserve the assertion; `[]` clears it. When replacing sessions, reviewers must preserve a genuinely complete sequence or explicitly clear the marker.

- Session fields: `date` (required), `cohort`, `start_time`, `end_time`, `timezone`, `location_kind`, `venue_id`, `offsite_name`, `offsite_address`, `offsite_city`, `offsite_lat`, `offsite_lng`. Date/time strings are ISO; time is local wall time. Missing time/timezone keys snapshot listing defaults at replacement time; explicit null means unknown. Later partial updates to listing defaults preserve session snapshots. End time must follow start time on the same local day; overnight sessions are not modeled. Timezone is an IANA name, or null = unconfirmed. No inferred UTC instants/DST resolution.
- Listing `venue_id` is the organizer and default actual venue. `location_kind` is `venue` (existing default), `offsite`, `unknown`, or `multiple`. Offsite has a required name and separate optional address/city/coordinate pair; missing city is visibly unknown. Legacy writes supplying `offsite_name` without location kind select offsite. Explicit location kind wins. Occurrences default to `inherit` (listing location); `venue` requires an actual `venue_id`; `offsite` and `unknown` override it. Cards/pages summarize actual session venues, not the organizing gym. Radius searches use actual confirmed-session locations in the selected date window, or listing location if there are no sessions; unknown coordinates never borrow organizer coordinates.
- `one_off` requires start date (optional end bound); `multi_day` and `course` require ordered start/end dates. Bounds constrain sessions. One-off sessions must be on the start date. One-off/multi-day bounds can be the convenient authoritative event span; course bounds are a term span, not proof of every date within it.
- `recurring` publication requires confirmed occurrences or a structured pattern: `recurrence: "weekly", weekday: 1..7` (Mon–Sun), or `recurrence: "monthly", weekday: 1..7, month_week: 1..5 | -1` (-1 = last). Patterns also work on courses. They describe evidence and **never generate dates or satisfy date filters**. No arbitrary rule engine. `unscheduled` has no dates/times/occurrences; shown only with the reveal toggle, never in date-filtered results.
- `sources` (HTTP(S) evidence links) remain internal. `checked_on` means sources last checked. Code maintains `catalogue_updated_on` only for substantive listing/session changes; source checks, evidence links, legacy prose changes and identical reimports do not refresh it. The public footer shows only **Last updated**, using `catalogue_updated_on`. Legacy null means no established substantive-update date, so the public timestamp is omitted; `checked_on` is never used as a fallback or exposed as provenance. Both dates remain stored internally. No rebuild clock is used.
- **Who can take part, in full.** `ages` records the organizer's eligibility as they state it, including every alternative route in: "Ages 12+, or members of a competitive team or advanced climbing program", not "Ages 12+". An "or" on the source page is never dropped. If eligibility is unclear, record what is stated and put the doubt in `caveat`.
- Summaries describe what/who. Caveats only clarify uncertainty in displayed date/time/place. Prices, availability and booking logistics stay on the organizer's page.

### Complete-cohort activation (coordinator only, after review)

`20260919000000_add_complete_cohorts.exs` adds only the non-null array with empty default; it marks no records. Back up each destination DB before migrating. Then the only reviewed metadata update authorized in this pass is `Catalogue.Import.put_listing(%{id: 209, complete_cohorts: ["__unnamed__"]})` for Pebbles: omit sessions to preserve all existing dates/times/IDs. Verify its six-session evidence still matches `priv/repo/examples.exs` before applying. Do not run the whole examples script against existing destinations. Other records stay unknown. Worker verification migrated only the separate test DB; local/live activation remains pending.

### Small updates

```elixir
alias ClimbOntario.Catalogue.Import
# Evidence-only partial update: confirmed sessions and catalogue update date survive.
Import.put_listing(%{id: 28, checked_on: ~D[2026-09-17]})
# Explicit clear is validated; a recurring row still needs its structured pattern.
Import.put_listing(%{id: 28}, [])
# Named sessions at different actual places, on the same day (venue IDs must exist).
Import.put_listing(%{id: 17, cohorts: ["Morning", "Evening"], location_kind: "multiple"}, [
  %{date: "2026-10-17", cohort: "Morning", start_time: "09:00:00", end_time: "12:00:00",
    timezone: "America/Toronto", location_kind: "venue", venue_id: 1},
  %{date: "2026-10-17", cohort: "Evening", start_time: nil, end_time: nil, timezone: nil,
    location_kind: "offsite", offsite_name: "Park", offsite_city: "Toronto"}
])
```

The last snippet demonstrates the contract, not reviewed event evidence; use `priv/repo/examples.exs` for the three actual examples.

## Dedicated Fly test deployment — 2026-09-17

Keith authorized a publicly reachable, no-password HTTPS test URL: **https://climb-ontario-keith.fly.dev/**. This is a dedicated personal app, separate from Dot/workspaces. The initial deployment was reachability-only. Keith subsequently authorized the reviewed OpenCage replacement for limited public testing; see the OpenCage update below. This is not a licensing exemption or unrestricted production approval.

| Resource | Actual value |
|---|---|
| App / organization | `climb-ontario-keith` / personal (KeithHassen) |
| Region / Machine | `yyz` / `874227b0321039` (`catalogue-primary`) |
| Compute | Exactly one shared CPU, 512 MB RAM |
| SQLite volume | `vol_v8ek9mmjowkz535v`, `catalogue_data`, encrypted 1 GB, mounted `/data` |
| DB | `/data/catalogue.db` |
| Image | `registry.fly.io/climb-ontario-keith:initial-catalogue` |
| Image digest | `sha256:c2f31046094eabff4aa202b9611a86e6c4359e9dae6b07b09f84f2f307dbc3a4` |
| Ingress | Shared IPv4 `66.241.125.249`, IPv6 `2a09:8280:1::191:8e3f:0`; no dedicated IPv4 |
| Health | `/healthz`, minimal `ok`, checks DB table access; probe sends `X-Forwarded-Proto: https` |

Boot uses `bin/release-start.sh`: refuses absent/empty SQLite, runs migrations **on the attached Machine**, then starts the release. No Fly `release_command`, automatic seed/import, or overwrite on restart. `PHX_HOST` is the new host; interest capture is disabled in the production build, and no email integration exists. `SECRET_KEY_BASE` was generated in memory and passed by stdin to Fly secrets; credentials/secrets were not stored in source or image.

### Bootstrap and build evidence

A consistent SQLite backup was taken through a read-only connection: `tmp/pre-fly-20260917133710.sqlite` (0600). A separate fresh-schema snapshot copied only migration metadata, venues, listings and occurrences; the interests table was created empty. Local data/research was not modified. Snapshot `tmp/fly-bootstrap-catalogue.sqlite` (0600) passed integrity and FK checks; SHA256 `4461108db8a9f9a70589bee14ca3fadc3012c47cf3c11b032bd894c5cb786493` matched after private SFTP upload. Counts: 54 venues, 311 listings (302 published/9 held), 3941 occurrences, 576 source links, zero interest rows.

One maintenance Machine was started with `/bin/sleep infinity` and the new volume. After confirming no target DB existed, the verified staging file was renamed to `/data/catalogue.db`. The same Machine was then adopted by normal deploy (`--ha=false`); no second Machine/volume was created. Future deploys must preserve this volume and use `--ha=false`—never re-bootstrap an existing DB.

Remote Docker build passed (154 MB image). `.dockerignore` is an allowlist: no app/dev/test databases, research evidence, caches/raw Google data, local deps/build outputs or credentials enter the build context. At initial bootstrap the three runtime geo JSON files were Google-derived. The OpenCage update below replaces those inputs; this paragraph records historical bootstrap evidence. Initial HTTP probe redirected due to production SSL; adding the forwarded-protocol header corrected health routing without another image build.

### Operation / stop

Run scoped CLI commands using the approved credential wrapper, not a token in command arguments/files:

```
flyctl deploy --app climb-ontario-keith --ha=false --remote-only
flyctl machine restart 874227b0321039 --app climb-ontario-keith
flyctl machine stop 874227b0321039 --app climb-ontario-keith
```

The stop command stops compute and preserves the charged volume. Because auto-start is enabled, a subsequent request can restart it. For a durable pause, run `flyctl machine update 874227b0321039 --app climb-ontario-keith --autostart=false --yes`, then the stop command; also set auto-start false/minimum-running zero in reviewed config before any later deployment. Do not destroy the volume. Keep protected independent backups and test restoration before relying on the service. The single local volume is a single failure domain. Fly scheduled volume snapshots currently have five-day retention.

Coordinator-verified current pricing assumption: **$3.56/month compute + $0.15/month for 1 GB volume**, plus applicable remote build, snapshot/backup and egress charges. No free-tier assumption. Volume charges continue while compute is stopped. No HA/replicas, managed DB or email provider included. Resizing/scaling requires separate approval.

Public verification: HTTPS health/home, London+OCF (two chronological results), November Saturday date+keyword filtering, connected LiveView keyword update, detail CTA/back link and new-host OG/share URLs. A deliberate Machine restart passed health 1/1 and preserved 302 published/9 held, 3941 occurrences, 576 source links and zero interest rows; integrity remained `ok`, production interest remained `false`. Local suite: 56 passing; warnings-as-errors clean. No GitHub pushes, commits, preview restart, or modifications to other Fly apps.

## Configuration and known limits

- `RESEARCH_DB`: seed-only read-only SQLite path; `mix catalogue.seed` creates missing unpublished skeletons and never overwrites them. Not needed for import/test work.
- `PORT`: use the reviewed dev port; 4000 belongs to the host app. Production would need `DATABASE_PATH`, `SECRET_KEY_BASE`, `PHX_HOST`; dedicated test deployment is authorized above.
- No automatic server restart after a box restart, no Open Graph image. Public previews require a publicly reachable URL.
- Bundled geo now uses the accepted OpenCage selection. Trial testing restrictions, unknown account entitlement, and unaudited input-address provenance remain explicit limitations; credits are not a claim of full licence clearance.

## OpenCage limited-test update — 2026-09-17

Keith authorized merge/deploy/verify of the accepted final review: 54 gyms, 418 places, 524 FSAs; 11 rejected inputs excluded. `bin/bundle-opencage.py FINAL_REVIEW_DIRECTORY` reads only `final-review.json` selected points and original OpenCage `results.json` source annotations/licences. It makes no network calls. Runtime data is local-only; no provider API key is configured in the browser or needed by the release.

`Geo` compiles these files via external-resource dependencies. Remote Docker builds exclude local `_build`, provider caches, research/DB backups and retired fetch scripts. City resolution uses exact normalized reviewed names, not prefixes. Approximate gym points are suitable only for distance estimates; Map links use the actual venue's organizer street address. Metadata remains in `priv/geo/gyms.json` keyed by `source_gym_id`, so no schema migration is needed.

Public credits are visible in the shared footer and `/location-data`. OpenCage API `licenses` points to https://opencagedata.com/credits; source-related OSM annotations are retained. Unrelated response enrichments (such as what3words) are not bundled. The reviewed retry for Kanata has only summarized evidence, recorded as `retry` rather than fabricated response annotations.

Official policies checked: https://opencagedata.com/api (Caching: permanent storage even on free trial or after leaving); https://opencagedata.com/pricing (trial is testing-only; production should become paying); https://opencagedata.com/terms (underlying source licences remain the user's responsibility). Response limit 2,500 suggests trial but does not establish actual account entitlement, which is unknown. No plan purchased, new geocoding calls, or legal-clearance claim. Approved scenario is limited non-mission-critical public testing, not a production launch.

One-time live coordinate operation: consistent `VACUUM INTO` backup `/data/catalogue-pre-opencage-20260917.sqlite`, then explicitly invoke the separately uploaded `/data/apply-live-coordinates.exs` using release RPC after deploying. It verifies the exact 54 source IDs, updates only lat/lng in a transaction, checks all non-coordinate venue and listing/session/interest data unchanged, integrity/FKs, then writes `/data/opencage-coordinates-20260917.applied`. It is never invoked on boot and refuses a second application. Never replace the live DB with a local snapshot.

Full resource/image IDs, verification, protected backup paths, retirement scope and rollback/stop instructions: `/workspace/dot-files/knowledge/ontario-gyms/opencage-full-evaluation/deployment-report.md`. Historical research copies remain untouched; no universal purge or input-address provenance proof is claimed.
