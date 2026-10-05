**Goal**
For each gym in your list, one at a time: turn its saved capture (what's new or changed since {{LAST_REFRESH}}) into catalogue changes and import them into the **dev** database. Then move to the next gym. Best effort: only what the saved evidence supports, never invented, no browsing.

**For each gym**
1. Read its capture (`index.md`, then the raw `evidence/` files you rely on) and its current listings in `{{DEV_DB}}` (SQLite, read-only for you).
2. For each finding, look for an existing listing first: `research/lookup.py {{DEV_DB}} <url or booking ID>`, `research/similar.py {{DEV_DB}} --gym "<gym>" --title "<title>" --from <date> --to <date>`, and read the gym's listing list (listings without dates won't show up in similar.py). Existing listing → `update` with its `id`. Otherwise → `new`.
3. Write the gym's `proposals.json` in its run folder (format: §3 of `docs/weekly-refresh.md`; rules: `docs/research-rules.md`). If the file already has entries from an earlier pass, check and reuse them. Set `"approved": true` on what you import. Anything risky or unclear (closures, conflicting sources, removing sessions, a possible duplicate) stays `"approved": false` with a one-line `"why"`.
4. Import: `cd {{REPO}} && flock /tmp/betasheet-dev-import.lock research/apply.sh dev <run folder>`. If the importer rejects an entry, fix it and rerun (successes are skipped).
5. Write a short `notes.md` in the run folder: one line per change, then anything held and why, then any judgment call you made (a format or interpretation that wasn't obvious).

**Rules that matter most**
- Updates carry only the changed attrs. A `sessions` array replaces ALL of a listing's sessions: include every existing one you keep (past ones too), or leave `sessions` out.
- Times and dates only from evidence; unknown times are explicit null. Never generate dates from a weekly pattern.
- Each entry has evidence: URL, a short exact quote from the raw evidence file, and its path.
- OCF competitions are handled by the OCF pass (`ocf.md`); leave them alone here. Past events need nothing.
- `link` is a page a visitor can open on its own; embed and widget addresses go in `sources` (see `docs/research-rules.md`).
- Write only in your gyms' run folders. Never touch production.

Update `{{PROGRESS}}` after each gym. Finish with counts imported / held per gym.
