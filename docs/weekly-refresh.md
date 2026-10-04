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
   "last_copy": "runs/2026-10-04/gyms/junction-climbing-centre/pages/junction-climbing-centre-web-page.txt",
   "active": true, "origin": "research channel"}
  ```

  `type` is `web page`, `booking page`, `instagram`, `facebook` or `ocf`. `fetch` is `box` (read from
  this machine) or `browser` (needs Keith's logged-in browser). Instagram entries also keep
  `seen_posts`, the post IDs already looked at. The fingerprint is a hash of the page's readable text,
  so an unchanged fingerprint means nothing to read.

- **`DATA/runs/<date>/`**: one folder per run, committed when the run is done. The source list above is
  last week's and stays read-only during the run. Work is split into **parts**: one per gym, plus
  `shared` for sources several gyms share, like the OCF calendar. Each part writes only into its own
  folder, so several researchers can work at once without touching the same file.

  | File | What |
  |---|---|
  | `gyms/<part>/checks.json` | one line per source checked: unchanged, new, changed or error, with its new fingerprint |
  | `gyms/<part>/pages/` | readable text of each source that changed, and a `.diff` against last week |
  | `gyms/<part>/proposals.json` | that part's drafts, each with evidence |
  | `gyms/<part>/source-changes.json` | sources to add, fix or deactivate (step 6) |
  | `proposals.json` | all parts' proposals, merged, for Keith to approve |
  | `duplicates.json` | possible duplicates found at merge |
  | `report.md` | for Keith |
  | `applied.json` | what was applied, to dev and to prod |

- **Listings in production**, each with its source links in `sources`. Those links carry the IDs that
  recognise an event next time (booking codes, Instagram post IDs, OCF event addresses).

## 1. Start (once per run, by whoever coordinates)

```
export FLY_API_TOKEN=$(../betasheet-data/betasheet/ops/fly-token.sh)
bin/pull-prod-db.sh                 # fresh production snapshot into DATA/snapshots
python3 research/run.py dev         # local dev database = that snapshot
python3 research/run.py start       # creates DATA/runs/<today>/ and a folder per part
python3 research/run.py parts       # the parts, their gyms and how many sources each has
```

Every researcher checks for duplicates against this same dev copy. If several researchers work at once,
give each a set of parts; a part belongs to one researcher only, including its Instagram and Facebook.
The browser helper's lock lets them share Keith's one browser.

## 2. Check a part's websites and booking pages

```
python3 research/run.py fetch <part> [<part> ...]
```

This reads the part's active `box` sources and records each as unchanged, new, changed or error. For new
and changed ones it saves the text, and a diff against last week. An error is usually a dead link or a
blocked page: note it, and fix the source list in step 6.

Booking widgets and some gym sites draw their schedules with scripts, so the plain read can miss dates.
When a changed page looks empty of schedule, read it with `agent-browser` on this box instead.

## 3. Check a part's Instagram and Facebook through Keith's browser

These need Keith's desktop browser (`lego outpost list` shows it online). Connect once per session with
`lego browser connect --port 9013`. Then for each of the part's `browser` sources:

```
research/browser_read.sh <url>  > /tmp/<source-id>.txt
python3 research/run.py record <part> <source-id> /tmp/<source-id>.txt
```

`browser_read.sh` waits for the page to load, prints its text and the post links it shows, and holds a
lock, so several researchers can share the one browser safely. A plain `lego browser <url>` misses
Instagram posts, which load after the page; always use the helper. It uses the research tab (4 by
default); never navigate Keith's own tabs.

`record` fingerprints the text, and for Instagram lists `new_posts`: post IDs not seen before. Open
each new post with `research/browser_read.sh <post-url> 3` and read the caption. On a first run every
post is new; read the ones from the last three months. Ignore stories; they are gone within a day.
Never like, follow, message or change anything in Keith's accounts.

If the desktop is offline, finish everything else and list the unchecked accounts in the part's notes.
The next run picks them up. `python3 research/run.py status` shows each part's progress.

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

## 5. Write proposals

Each part's proposals go in `gyms/<part>/proposals.json`:

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

- `ref`: a short name, unique within the part. Merging prefixes it with the part.
- `action`: `new`, or `update` with the listing's `id`. An update sends only the fields that change.
  `sessions` replaces all of the listing's sessions; leave it out to keep them.
- New listings get their ID when applied, and are published once approved.

When the part is finished, write `gyms/<part>/notes.md` for Keith, short and in plain words:

- what was checked, and anything that couldn't be (dead links, offline browser);
- each proposal on one line: ref, title, new or update, what changed, and the evidence in a few words;
- possible duplicates you held back, and anything uncertain;
- source changes.

Then `python3 research/run.py done <part>`. That marks it ready for Keith's review. Keith reviews parts as
they finish and may ask for changes; fix them in the same part's files.

## 6. Keep the source list honest

Never edit `sources.json` during a run. Record source changes in the part's `source-changes.json`:

```json
{"add": [{"id": "junction-linktree", "url": "https://linktr.ee/junctionclimbing", "type": "web page",
          "fetch": "box", "gyms": ["Junction Climbing Centre"]}],
 "update": [{"id": "climb-muskoka-web-page", "url": "https://climbmuskoka.com/youth-programs"}],
 "deactivate": [{"id": "some-old-page", "note": "404 since October"}]}
```

- **Add** a page that lists events and isn't watched yet: a link-in-bio page, a new booking list, a new
  events page. Give it a unique `id`.
- **Update** a URL that moved. **Deactivate** a page that is gone, with a short note. Nothing is deleted.

## 7. Merge, report, and get approval (coordinator)

When every part is done:

```
python3 research/run.py merge
```

This builds the new `sources.json` from last week's list plus every part's checks and source changes,
gathers every part's proposals into the run's `proposals.json`, and checks each new proposal against
the catalogue and against the other proposals for possible duplicates (`duplicates.json`).

Then write `report.md` for Keith, short and in plain words: counts of sources checked and changed; each
proposal in one line (gym, title, what changed, why); possible duplicates; anything blocked or
uncertain; source list changes. Send it to Keith and wait. He approves by ref, or asks for changes. Set
`"approved": true` in `proposals.json` only on what he approved.

## 8. Apply what Keith approved

```
research/apply.sh dev       # validates against the local copy first
research/apply.sh prod      # then production, with the same listing IDs
bin/pull-prod-db.sh         # snapshot after the change
```

Both steps record their results in `applied.json`. Re-running after a fix skips what already succeeded.
If dev reports an error, fix the proposal and run dev again before touching prod. Then spot-check one
changed listing on https://betasheet.ca.

## 9. Commit the run

In `../betasheet-data`: commit the run folder, the new `sources.json` and the snapshot together, one line,
for example `Weekly refresh 2026-10-11: 6 new, 3 updated, 2 sources added`. Push. Code changes, if any,
go to the code repo separately.

## Once a month

Look for gyms we don't know yet: new openings, university or community walls, gyms that rebranded. A new
gym needs a venue first, which is a code-side change: ask Keith before adding one. The six gyms with no
sources yet (see `sources.json` coverage) are part of this pass.
