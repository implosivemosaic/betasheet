**Goal**
Check OCF discovery and event details once centrally for all gyms. Find new competitions AND changes
to known upcoming events. Follow `docs/weekly-refresh.md` and `docs/research-rules.md`.

**Inputs**
- https://www.climbontario.ca/events and the season news/calendar.
- Current OCF listings and occurrences in `{{DEV_DB}}` (read-only), including their source/event URLs.
- Previous successful per-source snapshots and unresolved findings from the run handoff.
- Output folder: `{{RUN_DIR}}/shared/ocf/`.

**For every upcoming event**
1. Use the index to discover dates, titles and hosts. Open each event's own page even when those fields
   already match. Revisit upcoming catalogue event URLs absent from the index too.
2. Read the full detail page and any linked schedule needed to establish times. Capture category
   dates, climbing start/end times, separate check-in information, location, eligibility and
   registration URL. Preserve “proposed schedule” wording. Distinct scheduled categories may need
   separate sessions; age eligibility alone does not create sessions.
3. Compare both index and detail evidence with their own previous checkpoints and current catalogue.
   Save each distinct URL as an active source; identical URLs shared by gyms are checked once.
4. Write one coverage row per event in `coverage.json`: listing ID when known, event URL, captured_at,
   evidence path, status (`checked` or `partial`), changed fields and follow-up. Unchanged date/venue
   is not grounds to stop before checking details. Missing stored times mean unrecorded; look for them.
5. Propose only supported changes, including new times/registration details on existing events. Dates
   absent from an index or an unreadable page do not establish cancellation. Preserve existing sessions
   unless a supported change is explicitly proposed for final review. Unknown facts stay null.

**Output and boundary**
Save raw evidence, separate source checkpoints, `coverage.json`, `proposals.json` (`approved: false`),
`decisions.json` and short `notes.md`. Each proposal has a URL, short exact quote and saved evidence
path. Retry a failed page once, record the gap and continue. New host venues and unresolved facts go
in the coordinator's final review, not intermediate questions to Keith. Never publish.

The coordinator checks every coverage row before accepting “no changes”, merges these candidates
with gym proposals, and validates one isolated combined set. Event #303's December 2026 timetable
was missed when the November pass stopped at the index: matching index entries must still receive
this detail-page check.
