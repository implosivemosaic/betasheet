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
- **Every highlighted date is accounted for.** A date shows a session, answers "no
  available times", or is listed in `unread` with the date it was asked about. A date
  that was never clicked, or whose detail came back as nothing but portal chrome, is a
  hole in the evidence — never an absence of sessions, and never a removal.
- **A month sequence is checked, not counted.** The window is the requested months
  starting at the panel the widget opened on, so a repeated month or a skipped one is
  stated as a problem and the capture is `partial`. Counting panels answers a different
  question and hides exactly that failure. Redpoint's live run proves the case: clicking
  a spillover date moves the datepicker, so "Next Month" skipped December while three
  panels were still read.
- `failed` splits into an unreadable document (`challenge`: Cloudflare interstitial,
  JavaScript shell, hard 404, empty body, navigation-only render) and a `notice`
  (`plan-inactive`, `nothing-here`, `file-deleted`) — the source answered, but not with a
  calendar. A notice is a finding for a reviewer: not a gap, not an empty schedule, and
  not a cancellation.
- Shell detection matches exact phrases, never vendor words. `not found` appears in Hub's
  marketing copy and `recaptcha` in a footer on 14 real pages; both stay `read`.

**Verdict** (from `compare.py`): `unchanged`, `changed`, `new-baseline`, `incomplete`.

- **A page-only capture is its own channel.** When the offering description is readable
  and the calendar markup is absent, the record carries `calendar_observed: false` and a
  `page` block. It compares on page text, reports "page content changed; interpretation
  pending", never claims a session, and never advances a calendar baseline. Its coverage
  block describes a page — a page-only capture that declared a three-month window it
  never read would be blocked from setting the page baseline it actually earned.
- **Incomplete captures still say what they saw.** An ineligible capture returns
  `incomplete` with `provisional: true` and the additions and edits it independently
  observed — new dates in the months it did read, posts above a feed it stopped short of.
  Removals, moves and availability changes are never carried: those need the whole window.
- Eligibility comes before comparison. If either capture is not `read`/`read-empty` the
  answer is `incomplete` and the baseline stands. Two verified empty calendars are
  therefore `unchanged`; two failures can never be.
- The fingerprint covers what is still bookable — date, start, end, cohort from the
  current capture's date onwards. The read window, elapsed dates and booking state are
  excluded, so a calendar that only aged hashes equal.
- Removal is claimed only inside the months the current capture read. Elapsed entries and
  entries from unread months are listed under `suppressed` with a reason.
- A time change is one `moved` entry when the pairing is unambiguous; several legitimate
  slots on one date stay `added`/`removed`, flagged `ambiguous_pairing`. A session whose
  time the source never announced (`start: null`) is never paired into a move: an unknown
  time is not evidence of a change, so the two observations stay visible and flagged.
- Session ordering is total and null-safe: unknown sorts first, so a fingerprint never
  compares `null` with `"18:30"` and never depends on the order a capture listed things
  in.
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
contract says: Rock Gym Pro 18 failed / 53 read-empty / 164 read, Redpoint 1 failed plus 1
notice / 10 read-empty / 12 partial / 2 read, pages 38 not a page (4 notices) / 289 read.

The 12 partial Redpoint captures are the finding, not noise: they were taken by the tool
that read the same month twice and skipped December, and their stored panels say so once
the sequence is checked.

## Live evidence

Captured with Chrome on playground (`wren-refresh-browser`), kept in
`wren-tools/live-capture/`:

| file | what it proves |
|---|---|
| `alt-rock-fix2.rgp.json` | 3 contiguous panels, 78 highlighted dates, 77 read, 369 sessions, 1 unread date (15 Nov never answers, even after 28s) → `partial` |
| `ethos-kilter-fix2.rphq.json` | panels November, **December**, January after the panel restore → `read`, complete |
| `pageonly-probe2.rgp.json` | an offering page with no widget → page coverage, `read`, complete |

The 369 sessions against one date per click is the old tool's blind spot: an offering with
three sessions a night was captured as one, so a baseline taken by it understates the
catalogue and needs re-capturing rather than diffing.
