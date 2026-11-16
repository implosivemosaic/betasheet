# Registry — where each source's baseline lives, and when it moves

`betasheet-data/betasheet/sources.json` is the only state carried from one run to the next.
Wren's `extract.py` says what a capture read; `compare.py` says what changed. This file says
which capture is the baseline, and the one rule that moves it.

## The source record

Existing fields stay (`id`, `url`, `type`, `fetch`, `gyms`, `active`, `origin`, `useful_for`, …).
`last_copy`, `fingerprint`, `last_checked` and `coverage_note` are folded into three records:

```json
{"id": "alt-rock-booking-page-3", "url": "https://app.rockgympro.com/b/?bo=…",
 "type": "booking page", "gyms": ["Alt. Rock"],
 "system": "rockgympro", "coverage_contract": "calendar-3-months", "aliases": [],
 "baseline":     {"capture": "runs/2026-11-11-refresh/gyms/alt-rock/evidence/alt-rock-booking-page-3.rgp.json",
                  "run": "2026-11-11-refresh", "captured_at": "2026-11-12T14:52:10+00:00",
                  "outcome": "read-empty", "evidence": "zero-available-days",
                  "fingerprint": null, "recovered": true},
 "ineligible":   null,
 "last_attempt": {"run": "2026-11-11-refresh", "capture": "…same path…", "captured_at": "…",
                  "outcome": "read-empty", "evidence": "zero-available-days", "verdict": "new-baseline"}}
```

- `system` picks the extractor: `page`, `rockgympro`, `redpoint`, `instagram`, `facebook`.
  `coverage_contract` is `web-page`, `calendar-3-months` or `social-window`.
- `baseline.capture` is the capture file `extract()` reads, relative to `betasheet-data/betasheet/`.
  `recovered: true` marks a baseline rebuilt from November evidence rather than declared by a tool.
- `ineligible` keeps a pointer that failed validation (a challenge page, a 404) for history. It is
  never compared and is cleared when a real baseline replaces it.
- `aliases` holds only verified alternative URLs, each with its evidence. Decoration-only differences
  need none; similar URLs are never merged on resemblance.

## A run

```
runs/<run>/sources/<id>/   one folder per source per run, whichever gym needed it
  <id>.rgp.json …          the capture files the tools write (tools/page.py, rgp.py, rphq.py, socials)
  verdict.json             the capture's outcome and eligibility, with
                           compare_source(extract(baseline), extract(current)) unedited inside
  review.json              which gyms reviewed it: {gym: {at, by, note, capture, sha256}}
  attempts/<n>/            earlier attempts in this run, moved aside before a recapture
runs/<run>/gyms/<gym>/     the write-up, as now: proposals.json, decisions.json, notes.md
```

A shared source is captured once per run. Capturing it again while an eligible capture exists
returns the existing verdict; `--force` recaptures and clears its reviews.

## Commands

```
refresh.py capture <id> --run R --by NAME     run the source's tool, then ingest
refresh.py ingest  <id> --run R --by NAME     a capture already saved in the folder (socials)
refresh.py review  --run R --gym G [--source ID] [--all-gyms] --by NAME --note "…"
refresh.py status  --run R [--gym G]          per source: outcome, verdict, reviews, what close will do
refresh.py close   --run R [--dry-run]        the run's last step: the only place a baseline moves
refresh.py register <url> --gym G --type T    a source found during the run
refresh.py recover --from runs/2026-11-11-refresh [--apply]
```

## The one rule: a baseline moves only at close

`close` records `last_attempt` for every source captured in the run, then advances `baseline` to
the run's capture only when all of these hold:

1. the capture's outcome is `read` or `read-empty` (so `partial` and `failed` never touch a baseline);
2. the verdict is `unchanged`, `changed` or `new-baseline` (never `incomplete`);
3. the verdict is `unchanged`, or every gym in `gyms` has reviewed it (`--all-gyms` lets one owner,
   such as the OCF collector, review for all of them). A review is bound to the capture file's
   hash, so a recapture needs a fresh review.

Otherwise the old baseline stands and `close` says why. There is no `pending` field: a change nobody
reviewed is still a difference from the unmoved baseline, so it reappears next run. Held items live
in the decision ledger, as they do now.

Close is the last step, after the write-ups are consolidated, so a collector that dies mid-gym never
moves a baseline past a change it didn't write up.

## Writes

Only `close`, `register` and `recover` write `sources.json`. Each takes `flock` on
`sources.json.lock`, re-reads the file, changes only its own fields and replaces the file atomically.
`flock` is released when the process exits, so a crashed agent cannot leave a stale lock.
Captures lock their own source folder the same way. Social captures share one browser lock.

## Recovery from November

`recover` writes a report and a proposed `sources.json`; `--apply` replaces the registry after review.

- Captures are matched to source ids by the existing pointer, by id, or by decoration-only URL
  normalisation. Captures with no source are listed for registration, never attached by resemblance.
- `baseline` becomes the newest matched capture whose `extract()` outcome is `read` or `read-empty`.
- An existing pointer whose file extracts as a failure (a challenge page or 404) moves to `ineligible`.
- Social captures become `last_attempt` with outcome `partial` and the post ids they recorded, so the
  next reader knows where to stop. They get a baseline from the next social-window capture.
- Notices (`plan-inactive`, `file-deleted`, `nothing-here`) become findings in the report, one per
  source and notice, with every evidence file that shows it.
- `--register-discovered` registers captures of followed links (calendars and pages) as sources
  of their own; social post-detail captures stay evidence only.

## Tests

`python3 research/refresh/tests/run.py registry` runs the registry cases end to end against real
`extract()` and `compare_source()`; `python3 research/refresh/tests/run.py` runs every case.
