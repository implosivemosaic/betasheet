# Weekly refresh

Once a week: check every source we watch, find events that are new or changed, propose listings under
`docs/research-rules.md`, and after Keith approves, put them live. Nothing is published without approval.

Paths below are from the code repo, `/data/workspace/repos/climb-ontario`. `DATA` is
`../betasheet-data/betasheet`.

## What the run keeps

- **`DATA/sources.json`**: every place we watch. One entry per URL:

  ```json
  {"id": "junction-climbing-centre-web-page", "url": "https://www.junctionclimbing.com/youth-programs",
   "type": "web page", "fetch": "box", "gyms": ["Junction Climbing Centre"],
   "last_checked": "2026-10-04", "fingerprint": "9c640f090bf8d52b",
   "last_copy": "runs/2026-10-04/pages/junction-climbing-centre-web-page.txt",
   "active": true, "origin": "research channel"}
  ```

  `type` is `web page`, `booking page`, `instagram`, `facebook` or `ocf`. `fetch` is `box` (read from
  this machine) or `browser` (needs Keith's logged-in browser). Instagram entries also keep
  `seen_posts`, the post IDs already looked at. The fingerprint is a hash of the page's readable text,
  so an unchanged fingerprint means nothing to read.

- **`DATA/runs/<date>/`**: one folder per run, committed when the run is done.

  | File | What |
  |---|---|
  | `report.md` | what was checked, new, changed, possible duplicates, blocked, source list changes |
  | `checks.json` | one line per source checked: unchanged, new, changed or error |
  | `pages/` | readable text of each source that changed, and a `.diff` against last time |
  | `proposals.json` | the drafts, each with evidence, for Keith to approve |
  | `applied.json` | what was applied, to dev and to prod |

- **Listings in production**, each with its source links in `sources`. Those links carry the IDs that
  recognise an event next time (booking codes, Instagram post IDs, OCF event addresses).

## 1. Start

```
export FLY_API_TOKEN=$(../betasheet-data/betasheet/ops/fly-token.sh)
bin/pull-prod-db.sh                 # fresh production snapshot into DATA/snapshots
python3 research/run.py dev         # local dev database = that snapshot
python3 research/run.py start       # creates DATA/runs/<today>/
```

## 2. Check the sources this box can read

```
python3 research/run.py fetch
```

This reads every active `box` source, keeps unchanged ones untouched, and saves text plus a diff for new
and changed ones. Errors are listed in `checks.json`: dead links, blocked pages. Note each one in the
report, and fix the source list (step 6).

Booking widgets and some gym sites draw their schedules with scripts, so the plain read can miss dates.
When a changed page looks empty of schedule, read it with `agent-browser` on this box and save that text.

## 3. Check Instagram and Facebook through Keith's browser

These need Keith's desktop to be on (`lego outpost list` shows it online). For each active `browser`
source:

```
lego browser <url>  > /tmp/<source-id>.txt
python3 research/run.py record <source-id> /tmp/<source-id>.txt
```

`record` fingerprints the text, and for Instagram lists `new_posts`: post IDs not seen before. Open only
those posts. Ignore stories; they are gone within a day. Never like, follow, message or change anything
in Keith's accounts.

If the desktop is offline, finish the rest of the run and list the unchecked accounts in the report. The
next run picks them up.

`python3 research/run.py status` shows what is still unchecked.

## 4. Find what's new or changed

For every changed source, read the diff (or the whole page when it's new to us) and list each event it
shows. For each one:

1. **Same link or ID?** `research/lookup.py climb_ontario_dev.db <url-or-id>`
   - Found, same dates: nothing to do.
   - Found, dates or details moved: usually the next term or a correction. Propose an update, or a new
     listing for the new term.
2. **Same gym, alike name, overlapping dates?**
   `research/similar.py climb_ontario_dev.db --gym "<gym>" --title "<title>" --from <d> --to <d>`
   - A hit is a possible duplicate. Put it under "Possible duplicates" in the report and don't draft it.
3. **Neither:** a new event. Research it fully under `docs/research-rules.md` and propose it.

Past events need nothing: the site hides them by date.

## 5. Write proposals and the report

Each proposal in `proposals.json`:

```json
{"ref": "junction-winter-crushers", "approved": false, "action": "new",
 "gym": "Junction Climbing Centre",
 "attrs": {"title": "Junior Crushers — Winter 2027", "kind": "class", "schedule_kind": "course",
           "summary": "...", "start_date": "2027-01-08", "end_date": "2027-03-12",
           "ages": "Born 2016–2021", "audience": ["youth"], "confidence": "confirmed",
           "link": "https://app.rockgympro.com/b/?bo=...", "link_kind": "registration",
           "sources": ["https://app.rockgympro.com/b/?bo=...", "https://www.junctionclimbing.com/youth-programs"]},
 "sessions": [{"date": "2027-01-08", "cohort": null, "start_time": "17:00:00", "end_time": "18:00:00",
               "timezone": "America/Toronto"}],
 "evidence": {"url": "https://www.junctionclimbing.com/youth-programs",
              "quote": "Winter 2027 Season: 10 weeks - January 8-March 12"}}
```

- `ref`: a short unique name for the proposal.
- `action`: `new`, or `update` with the listing's `id`. An update sends only the fields that change.
  `sessions` replaces all of the listing's sessions; leave it out to keep them.
- New listings get their ID when applied, and are published once approved.

`report.md` is for Keith: short, in plain words. Counts of sources checked and changed; each proposal in
one line (gym, title, what changed, why); possible duplicates; anything blocked or uncertain; source list
changes. Then send Keith the report and wait. He approves by ref, or asks for changes. Set
`"approved": true` only on what he approved.

## 6. Keep the source list honest

During the run, edit `DATA/sources.json` directly:

- **Add** a page that lists events and isn't watched yet: a gym's link-in-bio page, a new booking list,
  a new events page. Copy an existing entry, give it a unique `id`, `"origin": "found <date>"`, and
  empty `fingerprint` and `last_copy`.
- **Fix** a URL that moved. **Deactivate** (`"active": false`) a page that is gone, with a short `note`.
  Don't delete entries; history matters.
- List every source change in the report.

## 7. Apply what Keith approved

```
research/apply.sh dev       # validates against the local copy first
research/apply.sh prod      # then production, with the same listing IDs
bin/pull-prod-db.sh         # snapshot after the change
```

Both steps record their results in `applied.json`. Re-running after a fix skips what already succeeded.
If dev reports an error, fix the proposal and run dev again before touching prod. Then spot-check one
changed listing on https://betasheet.ca.

## 8. Commit the run

In `../betasheet-data`: commit the run folder, `sources.json` and the new snapshot together, one line,
for example `Weekly refresh 2026-10-11: 6 new, 3 updated, 2 sources added`. Push. Code changes, if any,
go to the code repo separately.

## Once a month

Look for gyms we don't know yet: new openings, university or community walls, gyms that rebranded. A new
gym needs a venue first, which is a code-side change: ask Keith before adding one. The six gyms with no
sources yet (see `sources.json` coverage) are part of this pass.
