# Refresh — capture, extract, compare

The weekly run's memory: what a source looked like last time, and whether it changed.

Two functions do the work and neither writes anything:

| File | Role |
|---|---|
| `extract.py` | capture file → comparable record (`outcome`, `coverage`, entries) |
| `compare.py` | `compare_source(baseline, current)` → verdict |
| `replay.py` | every saved capture of a run, compared with itself; nothing may read `changed` |
| `tools/` | the live capture tools (`rgp.py`, `rphq.py`, `page.py`, `coverage.py`) |
| `tests/` | one case per rule; `python3 tests/run.py` needs no dependencies |

The registry — where a baseline lives and who may move the pointer — belongs to Sage.
This module returns a verdict and never advances anything: `compare_source` is the only
seam.

## Two questions, kept apart

A capture answers *what did we read*; a comparison answers *what changed*. Collapsing them
is what made the previous run report 165 of 562 sources as `unchanged` while holding no
comparable content at all.

**Outcome** (from `extract.py`): `read`, `read-empty`, `partial`, `failed`.

- `read-empty` needs positive evidence of a rendered, populated structure: a Rock Gym Pro
  month with parsed cells, a Redpoint month with day cells, a page whose text is the page.
  An empty array on its own proves nothing.
- `failed` splits into an unreadable document (`challenge`: Cloudflare interstitial,
  JavaScript shell, hard 404, empty body, navigation-only render) and a `notice`
  (`plan-inactive`, `nothing-here`, `file-deleted`) — the source answered, but not with a
  calendar. A notice is a finding for a reviewer: not a gap, not an empty schedule, and
  not a cancellation.
- Shell detection matches exact phrases, never vendor words. `not found` appears in Hub's
  marketing copy and `recaptcha` in a footer on 14 real pages; both stay `read`.

**Verdict** (from `compare.py`): `unchanged`, `changed`, `new-baseline`, `incomplete`.

- Eligibility comes before comparison. If either capture is not `read`/`read-empty` the
  answer is `incomplete` and the baseline stands. Two verified empty calendars are
  therefore `unchanged`; two failures can never be.
- The fingerprint covers what is still bookable — date, start, end, cohort from the
  current capture's date onwards. The read window, elapsed dates and booking state are
  excluded, so a calendar that only aged hashes equal.
- Removal is claimed only inside the months the current capture read. Elapsed entries and
  entries from unread months are listed under `suppressed` with a reason.
- A time change is one `moved` entry when the pairing is unambiguous; several legitimate
  slots on one date stay `added`/`removed`, flagged `ambiguous_pairing`.
- Availability (`available → full`, `waitlist`) is reported in `availability_changes`:
  never a schedule change, never a cancellation.
- Social identity is the post id — Instagram shortcode, Facebook `pcb` post id or `fbid`
  photo id, kept apart. A caption hash is content, never identity.

## Running it

```
python3 research/refresh/tests/run.py            # 52 cases, no dependencies
python3 research/refresh/replay.py [evidence-dir ...]
```

`replay.py` defaults to the November evidence in `betasheet-data/betasheet/runs/2026-11-11-refresh`.
Its outcome table is the check that the extraction still divides the corpus the way the
contract says: Rock Gym Pro 105 failed / 53 read-empty / 77 read, Redpoint 3 failed (1 of
them a notice) / 10 read-empty / 12 read, pages 38 not a page (4 notices) / 289 read.
