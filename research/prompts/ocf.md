**Goal**
Make every OCF competition in the catalogue match the Ontario Climbing Federation's season calendar. The calendar is the authority for dates, host gym and title. Best effort, nothing invented.

**Inputs**
- The calendar: open https://www.climbontario.ca/events with `agent-browser` and save its full text, plus each event page you rely on (an event page gives the host gym's street address; use it whenever the calendar says only a brand such as "Hub Climbing").
- Current OCF listings: `select * from listings where ocf = 1` in `{{DEV_DB}}`, with their occurrences.
- Output folder: `{{RUN_DIR}}/gyms/shared/`.

**For each calendar event**
- Listed and matching: nothing to do.
- Listed but different (dates, host gym, title): an `update` with only the changed fields. Use the calendar's title with the date, e.g. `OCF Speed U13/ U15 U17/ U19/ U21 /SR — 2026-11-22`. If the calendar drops a day, replace the sessions with the calendar's days; that removal is approved.
- Not listed: a `new` OCF competition at the host gym (`kind: competition`, `ocf: true`, `confidence: tentative` until details are posted, unknown times null).
- Host gym not in our venues: don't add it. Note the gym, address and event in `notes.md` for Keith.

**For each OCF listing not on the calendar** (past events aside): set `published: false` and say why in `notes.md`.

Write `proposals.json` (approved: true, evidence with the calendar URL, a short exact quote and the saved file) and import it: `cd {{REPO}} && flock /tmp/betasheet-dev-import.lock research/apply.sh dev {{RUN_DIR}}/gyms/shared`. Finish with what changed and anything for Keith.
