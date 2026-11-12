**Goal**
For each assigned gym, turn its saved capture into review-only catalogue proposals. Use only supported facts; send concrete evidence gaps to the coordinator for bounded follow-up. The coordinator owns combined validation and the final human review under `docs/weekly-refresh.md`.

**For each gym**
1. Read its capture (`index.md`, then the raw `evidence/` files you rely on) and its current listings in `{{DEV_DB}}` (SQLite, read-only for you).
2. For each finding, look for an existing listing first: `research/lookup.py {{DEV_DB}} <url or booking ID>`, `research/similar.py {{DEV_DB}} --gym "<gym>" --title "<title>" --from <date> --to <date>`, and read the gym's listing list (listings without dates won't show up in similar.py). Existing listing → `update` with its `id`. Otherwise → `new`.
3. Write `proposals.json` following `docs/research-rules.md`, with `approved: false` on every candidate and stable refs. Reconcile prior pending proposals and production receipts. Keep unsupported items separately with the missing fact and evidence.
4. If assigned batch validation, use your own pristine snapshot copy on playground and a separate validation-only package with `approved: true`. Inspect every APPLIED result, not just exit status. Send receipts to the coordinator; independent batch IDs are not production IDs. The coordinator validates the combined final set before requesting approval.
5. Write a short `notes.md` in the run folder: one line per change, then anything held and why, then any judgment call you made (a format or interpretation that wasn't obvious).

**Rules that matter most**
- Updates carry only the changed attrs. A `sessions` array replaces ALL of a listing's sessions: include every existing one you keep (past ones too), or leave `sessions` out.
- Times and dates only from evidence; unknown times are explicit null. Never generate dates from a weekly pattern.
- Each entry has evidence: URL, a short exact quote from the raw evidence file, and its path.
- OCF competitions are handled by the OCF pass (`ocf.md`); leave them alone here. Past events need nothing.
- If `link` is an announcement and the capture has a separate sign-up or ticket page, put it in `signup_link`.
- `link` is a page a visitor can open on its own; embed and widget addresses go in `sources` (see `docs/research-rules.md`).
- Write only in your gyms' run folders. Never touch production.

Update `{{PROGRESS}}` after each gym. Finish with proposed/held counts, net added sessions, preserved sessions and time changes separately. A successful import establishes schema validity, not factual correctness.
