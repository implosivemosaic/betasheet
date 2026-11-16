# Registry: where each source's baselines live, and what keeps unresolved changes

Two kinds of state carry from one run to the next, and they never stand in for each other:

- **Baselines**, in `betasheet-data/betasheet/sources.json`: for each source, the last capture
  that read it in full. The next capture is compared with it.
- **Findings**, in each gym's `runs/<run>/gyms/<gym>/decisions.json`: every change, first read
  and notice a comparison turned up, unresolved until that gym settles it (a `proposed` finding
  stays unresolved until its proposal is published).

A baseline moves as soon as a capture qualifies; it never waits for anyone's review. That is
safe because the change it moves past was saved as a finding first. A finding stays pending
when the source later drops what it reported: an announcement that disappeared before anyone
looked is still a pending finding, marked "no longer shown".

Wren's `extract.py` says what a capture read and `compare.py` what changed. `registry.py`
holds the rules below and is the only code that writes `sources.json`.

## The source record

Existing fields stay (`id`, `url`, `type`, `gyms`, `active`, `origin`, `useful_for`, …). The
November fields `last_copy`, `fingerprint`, `last_checked` and `coverage_note` are replaced by:

```json
{"id": "ajax-rock-oasis-booking-page-3", "url": "https://app.rockgympro.com/b/widget/?a=offering&offering_guid=…",
 "type": "booking page", "gyms": ["Ajax Rock Oasis"],
 "system": "rockgympro", "coverage_contract": "calendar-3-months", "aliases": [],
 "baseline":      {"capture": "runs/2026-11-11-refresh/gyms/ajax-rock-oasis/evidence/ajax-rock-oasis-booking-page-3.rgp.json",
                   "run": "2026-11-11-refresh", "captured_at": "…", "outcome": "read",
                   "evidence": null, "fingerprint": "…", "sha256": "…", "recovered": true},
 "page_baseline": {"capture": "runs/2026-11-19/sources/ajax-rock-oasis-booking-page-3/….rgp.json", "…": "…"},
 "calendar_gap":  {"since_run": "2026-11-19", "last_run": "2026-11-19",
                   "reason": "calendar markup not observed; page text read"},
 "ineligible":    null,
 "last_attempt":  {"run": "…", "capture": "…", "outcome": "read", "evidence": "page-only",
                   "calendar_observed": false, "verdict": "new-baseline", "findings": []}}
```

- `system` picks the extractor: `page`, `rockgympro`, `redpoint`, `instagram`, `facebook`.
  A Rock Gym Pro offering (`bo=`, `offering_guid=`) is a calendar; a widget index (`bw=`) is
  a discovery page, captured with `page.py` so its offering links are saved for checking.
- **A calendar source keeps two baselines.** `baseline` is its last full calendar read.
  `page_baseline` is its last read that found the offering's text but no calendar markup. A
  page-only read is compared with, and may replace, only `page_baseline`; the calendar
  baseline stays, and `calendar_gap` records since when the calendar has not been read.
  The gap closes only when a full calendar read replaces `baseline`. The first page-only
  read sets `page_baseline` and carries no finding: compared with the calendar's own render
  it would differ only in page furniture. Page reads compare with it from the next one on.
- `baseline.slot_coverage: "dates-only"` marks a Rock Gym Pro calendar read by the November
  tool, which kept one session per highlighted date. Its dates are evidence; its time slots
  are not complete. Such a source is in the recapture queue (`close.json` `recapture`,
  `status --gym`) until a full read replaces the baseline. Compared with it, a new date is an
  addition and a session it recorded that is gone is a removal, but a session on a date it saw
  goes to `slots_to_reconcile`: a `source_first_read` finding to compare with the catalogue,
  never a schedule change on its own.
- A calendar whose clicked days all answered "no available times" is a baseline only when
  the capture tool declared complete coverage: the answer alone proves neither an empty
  calendar nor a complete read.
- `anchor` (social baselines) is the newest post a later capture must read back to.
- `ineligible` keeps a November pointer that failed validation, for history. It is never
  compared and is cleared when a real calendar or page baseline replaces it.
- `aliases` holds only verified alternative URLs. Similar URLs are never merged.

## A finding

One record per gym citing the source, appended to that gym's `decisions.json` beside the
collector's own records:

```json
{"ref": "source-change-shared-web-page-2-f2ab5cc129", "kind": "source_change",
 "status": "pending", "gym": "Boulderz Climbing - Toronto", "gyms": ["…", "…", "…"],
 "source_id": "shared-web-page-2", "sources": ["https://…"], "run": "2026-11-19",
 "summary": "Page content changed; interpretation pending. New text includes “Winter Youth Camp…”.",
 "details": {"lines_added": ["Winter Youth Camp…"], "lines_removed": []},
 "capture": "runs/2026-11-19/sources/shared-web-page-2/shared-web-page-2.meta.json",
 "capture_sha256": "…", "baseline_capture": "…", "baseline_sha256": "…",
 "evidence": ["<baseline capture>", "<this capture>"], "provisional": false,
 "recommended": "…", "first_seen": "2026-11-19", "recorded_by": "refresh registry",
 "dispositions": []}
```

A gym's `proposed` disposition adds `"status": "proposed"` and
`"proposal": {"ref": "boulderz-climbing-toronto/winter-youth-camp", "run": "2026-11-19", "file": "runs/2026-11-19/gyms/boulderz-climbing-toronto/proposals.json"}`
to the record, and the same link to its entry in `dispositions`.

Kinds: `source_change` (page text, calendar sessions or posts changed; `provisional` when a
capture fell short of its coverage but still showed something new), `source_first_read` (a
source's first accepted read, to reconcile with the catalogue) and `source_notice` (the source
answered with a status notice such as `plan-inactive`; never a cancellation). A page change
says "interpretation pending" with the lines added and removed; nothing invents an event.

The ref is derived from the source, the baseline and the content, so the same change is
saved once per gym however often it is captured or closed. A provisional record and the full
read that later confirms it are separate records.

## A run

```
runs/<run>/sources/<id>/   the source's capture for this run, whichever gym needed it
  <id>.rgp.json …          what the capture tool wrote (page.py, rgp.py, rphq.py, social_ig.py, social_fb.py)
  attempts/<n>/            a forced recapture; earlier captures never move, so evidence paths hold
  verdict.json             the current attempt's outcome, the baseline it was compared with,
                           compare_source(...) unedited, and the refs of the findings it saved
runs/<run>/gyms/<gym>/     the collector's write-up, as now, plus the registry's findings
runs/<run>/close.json      what moved, the calendar gaps, and every unresolved finding from every run
```

A shared source is captured once per run: capturing it again while an eligible capture
exists reuses it; `--force` writes a new attempt.

## Commands

```
refresh.py capture  <id> --run R --session S --by NAME [--force]
refresh.py ingest   <id> --run R --by NAME        compare a capture already saved in the folder
refresh.py findings [--gym G] [--source ID] [--all]
refresh.py review   (--gym G ... | --all-gyms) (--run R [--source ID ...] | --finding REF ...)
                    --outcome no-change|held|proposed [--proposal GYM/REF [--proposal-run R]]
                    --by NAME --note TEXT
refresh.py status   --run R [--gym G]
refresh.py close    --run R [--dry-run]
refresh.py register <url> --gym G --type T
refresh.py recover  --from runs/2026-11-11-refresh [--out DIR | --apply] [--register-discovered]
```

## The rules

**Saving.** `ingest` saves a capture's findings the moment it compares it. `close` saves them
again before anything else, so a finding a collector's edit dropped is restored.

**Moving.** `close` then moves the baseline a capture was compared with when:

1. the capture's outcome is `read` or `read-empty` and its declared coverage is complete
   (social coverage reconstructed from a November summary never qualifies); and
2. the comparison is not `incomplete`.

Otherwise every baseline stands and `close` says why. `last_attempt` is recorded either way.

**Resolving.** Each gym disposes of its own record. `no-change` resolves it and `held` keeps it
pending with the note. `proposed` must name the proposal that carries the work as
`<gym-folder>/<ref>` (the bare ref when one gym is named). Refs are reused across seasons, so a
proposal is the pair (run, ref): it is looked up in the findings' own run, or in the later run
`--proposal-run` names, in the gym's own `proposals.json` or a coordinator's file of prefixed
refs. A run before the finding's is refused, since a proposal drafted before a change was seen
cannot carry it, and findings from several runs need `--proposal-run`.

The finding keeps that link and stays unresolved until a production receipt **from the
proposal's own run** records it published: a row in that run's `applied.json` with the exact
ref, `target: prod` and `status: ok`, as `research/apply.sh prod` writes it. A receipt for the
same ref from any other run published different work and never counts; `findings` lists such
receipts under the link so nobody mistakes them. A proposal carried into a later run stays
unresolved until the finding is relinked to the carried copy (`--finding REF --proposal-run`).
A held proposal leaves its finding open; a withdrawn or declined one is settled by disposing
the finding again by ref. The gyms of a shared source may all point at one proposal.

A review is bound to a capture: naming a run's sources touches only pending findings from each
source's current capture there, so a recapture needs its own review, and findings from earlier
captures or runs are named by ref. `--all-gyms` touches only records no gym has disposed of, so
neither kind of review overrides a gym's own entry or a proposed link.

## Writes

`close`, `register` and `recover --apply` write `sources.json` under `flock` on
`sources.json.lock`, re-reading the file and replacing it atomically. Findings are appended
under `flock` on each `decisions.json.lock`. The kernel releases a crashed holder's lock.

## Recovery from November

`recover` writes a report and a proposed `sources.json`; `--apply` replaces the registry.

- Captures match source ids by the old pointer, by id, or by decoration-only URL
  normalisation. Unmatched captures are listed (or registered with `--register-discovered`),
  never attached by resemblance.
- Each slot takes the newest matching capture that read its source in full: calendar reads
  become `baseline`, page-only offering reads become `page_baseline` with a `calendar_gap`.
  A Redpoint capture whose months repeat or skip is `partial` and never a baseline.
- A Rock Gym Pro calendar read by the November tool with sessions becomes a dates-only
  baseline. The recapture queue is built from those baseline evidence files and then resolved
  to source ids, so a capture filed under another name (`rgpS-coy-2` for
  `coyote-rock-gym-booking-page-2`) is still queued; the report lists both names.
- The report accounts for every capture file: each is a baseline, a last attempt, an
  ineligible old pointer, discovered, ambiguous, unreadable, or listed with the reason it was
  not used (an older capture, or a capture of another kind).
- A widget index captured as a calendar gets no baseline: it is a discovery page, recaptured
  with `page.py` next run.
- An old pointer whose file extracts as a failure (a challenge page, a 404) moves to
  `ineligible`. Social summaries become `last_attempt: partial` with their post ids.
- Recovery saves no findings: November's captures were already reconciled by its collectors.

## Tests

`python3 research/refresh/tests/run.py registry` runs the registry cases end to end against
the real `extract()` and `compare_source()`; `python3 research/refresh/tests/run.py` runs all.
