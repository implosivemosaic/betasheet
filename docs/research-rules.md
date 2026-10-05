# Research rules

How to turn what a gym publishes into a Beta Sheet listing. These rules apply to every research task:
the weekly refresh, one-off corrections and new gyms. When a rule and a page disagree, record what the
page says and flag it; never bend the page to fit the rule.

## Principles

- **Evidence first.** Every date, time, age, place, class and eligibility statement comes from a page you
  actually read. Keep the URL and a short quote (under 200 characters) for each proposal. Unknown stays
  empty: never guess, never fill from a pattern.
- **Record what a visitor attends.** One listing per thing a person signs up for or turns up to.
- **The organizer's page wins.** Prices, availability, registration conditions and booking details stay
  on their page, not ours.
- **Keep moving.** Leave an unsupported value empty, make the best supported listing, and note a short,
  specific follow-up. Don't redesign the schema or chase a borderline case for hours.

## What kind of listing

**Kind** (the badge): `competition` (set `ocf: true` only for officially sanctioned Ontario Climbing
Federation events, `false` for every other competition, including teams), `social`, `class` (lessons,
clinics, courses, programmes), `camp`.

**Schedule kind** (how it runs):

- `one_off`: one event on one day.
- `multi_day`: one event spanning consecutive days.
- `course`: a connected learning series, such as a fall term of weekly lessons. A series of competitions
  is not a course.
- `recurring`: independently attended repeats: drop-in nights, PA days, a monthly meetup, or an
  irregular set of confirmed dates.
- `unscheduled`: announced, but no usable dates yet.

## Sessions: dates and times

- Record only confirmed sessions, one per real date. A weekly pattern never creates dates; record the
  dates the page lists.
- Times are local wall time. Ontario venues use timezone `America/Toronto`.
- A date with no stated time is fine: leave the time empty. The site shows "time not announced" and
  calendar exports become all-day events.
- Record an end time only when the page states one. If the stated end is clearly a template placeholder,
  leave it empty and say so in your notes.
- An age category on a competition is eligibility, not a separate session. One OCF event for U11/U13/U15
  on one date is one session unless the page gives separate session times.
- When sources disagree on a date or time, keep what is undisputed, leave the disputed value empty, and
  add a short caveat. Never turn alternatives into extra sessions.
- Keep real gaps, such as no class on Thanksgiving. Don't fill them.

## Classes inside one listing (bundles)

When a gym sells one programme as several parallel classes, keep one listing and name each class in
`cohorts`. Each session's `cohort` says which class it belongs to.

- A bundle must say what its classes are split by: `bundled_by` is `age`, `level`, `format`, `day` or
  `mixed`. Each class records the fact that sets it apart in `classes` (`ages`, `level`, `format`).
- **Naming a class:** the name states what distinguishes it and nothing else: "Ages 6–8", "Level 2",
  "Adult/Child", joined with " · " when more than one applies. No weekday or time in the name; the site
  takes those from the sessions.
- Only to keep names unique, append " — " and the weekday (plus start time if still needed):
  "Ages 8–10 — Saturday". A `day` bundle's names are the weekday alone, or weekday plus start time when
  the same day runs twice: "Saturday 11:00".
- A single offering at several time slots, like one lesson bookable at four times, is not a bundle. It is
  one listing with several sessions.

## Who can take part

- `ages` records eligibility exactly as the organizer states it, including every alternative:
  "Ages 12+, or members of a competitive team or advanced climbing program", never just "Ages 12+".
  An "or" on the page is never dropped.
- `audience` tags who it is for: `youth`, `adult`, `family`, `adaptive`, `women`, `queer`. Tag every group
  the event is open to, not only the first one mentioned.
- If eligibility is unclear, record what is stated and put the doubt in `caveat`.

## Words on the page

- `title`: the organizer's name for it, plus the term or date when they run it more than once.
- `summary` (max 240 characters): what it is and who it is for. No prices, equipment, capacity,
  registration rules or research notes.
- `caveat` (max 160 characters): only to protect the accuracy of our own date, time or place, such as a
  disputed time. Never a booking condition or a warning banner.

## Links and sources

- `link`: the most specific organizer page for this listing (its booking page or event page), not the
  gym's home page when a better page exists. `link_kind` is `registration`, `event` or `gym`.
  Link to a page a visitor can open on its own. An embed or widget address (`…/embed`, Rock Gym Pro
  `/b/widget/…`, Beta `widgets.sendmoregetbeta.com`) goes in `sources`, not `link`. For Rock Gym Pro,
  link the standalone booking page `https://app.rockgympro.com/b/?bo=<offering ID>`; for other systems,
  link the gym's page that shows the booking (for example its events or programme page).
- `sources`: every page you read for it, most specific first. If a booking system, Instagram post, OCF
  page or Eventbrite page has its own address for this event, that address must be in `sources`: it
  carries the ID the weekly refresh uses to recognise the event next time.
- Pages that turned out useful for finding events go in the part's `pages.json` during the weekly refresh.

## Before proposing a new listing

1. `research/lookup.py <db> <url-or-id>`: does a listing already cite this page or ID?
2. `research/similar.py <db> --gym "<gym>" --title "<title>" --from <date> --to <date>`: same gym,
   alike name, overlapping dates?
3. A match on 1 is the same event: propose an update. A match on 2 is a possible duplicate: put it in the
   report for Keith and don't draft it. No match: propose a new listing.

The same ID can legitimately belong to two listings, for example one booking page carrying two terms.
Look at the dates before deciding.

## Reference decisions

Cases already settled, so they are not argued again:

- OCF Lead U17/U19/U21 on one date: one session, categories in `ages`, unknown start left empty.
- League of Ninjas Cup: competition, not OCF, `recurring` (independently attended dates), only undisputed
  dates confirmed, brief caveat for the schedule disagreement. It is ninja, not climbing.
- PA day camps: `camp`, `recurring` with each confirmed date, not one course spanning months.
- Junior Crushers: `class`, `course`, named classes with their observed dates and times.
- Price conflicts stay out of the public caveat.
- Holiday skips stay as real gaps in the sessions.
- We Are 6 Anniversary (Aspire Whitby): eligibility recorded with its "or" clause in full.
- Reach Development Team and Coyote Intro Plus: single offerings, not bundles.

## Field reference: the importer contract

`ClimbOntario.Catalogue.Import.put_listing(attrs, sessions)` returns `{:ok, listing}` (preloaded actual venues/sessions) or `{:error, changeset}`. Validation and all writes run in one transaction; failed listing/session inserts roll back the entire update. Errors may concern a listing or occurrence; SQLite integrity failures without a constraint name are attached to `:base`.

- `attrs` is an atom-keyed or string-keyed map of listing columns. `id` is the stable research event ID. Existing rows receive **partial updates**: omitted fields preserve values. New rows require `id`, organizing `venue_id`, `title`, `checked_on`. No new public IDs are invented during conversion.
- **Omit the second argument to preserve occurrences.** Supply a list to replace the entire set, including `[]` to clear it. Each item is a Date, ISO date string, or session map. Malformed sessions, duplicates, backwards dates/times, out-of-bound occurrences and invalid HTTP(S) URLs fail without changing either table. Sessions are confirmed evidence, never expanded from a pattern.
- `publish(id)` uses the same transaction and validation. Publishing requires kind, summary, schedule kind, confidence, link, link kind and at least one valid HTTP(S) evidence URL in `sources`. Drafts may keep an empty source list. Competitions require explicit `ocf: true` or `false`; other kinds leave `ocf` null. Discovery offers OCF, other competitions, social, class, camp. Legacy `label` and `schedule_note` are ignored by presentation; code owns badges/date/time/location wording. `label` is filled by code for the original DB constraint.
- `cohorts: ["Ages 6–8", "Ages 9–12"]` names the classes inside **one listing**. Session `cohort` must match one of these names (null = unnamed session). Classes without confirmed sessions display dates/times as unknown. No separate per-class product, booking or availability model.
- **Bundles.** Two or more named cohorts make a bundle, and a bundle must say what its classes are split by: `bundled_by` is `age`, `level`, `format`, `day` or `mixed`. Each class then carries the fact that sets it apart in `classes: [%{name: "Ages 6–8", ages: "6–8"}, ...]` (fields `name`, `ages`, `level`, `format`; `name` must be one of `cohorts`). `age` requires `ages` on every class, `level` requires `level`, `format` requires `format`, `mixed` requires at least one of them; `day` bundles differ only by weekday or time and need no `classes` entries. Day and time are never written into a class: they come from its sessions. Required for every new bundle and whenever a bundle's cohorts change; bundles written before this rule pass until then and are being backfilled by inspection of their source pages.
- **Naming a class.** The name states what distinguishes the class, and nothing else: the age band ("Ages 6–8"), the level or stream ("Level 2", "Development Team"), or the format ("Adult/Child"), joined with " · " when more than one applies. Never put the weekday or time in the name; the site derives "Monday class" and the times from sessions. The one exception is uniqueness: when two classes share the same facts and differ only by day, append " — " and the weekday (plus start time if still ambiguous), as in "Ages 8–10 — Saturday". For a `day` bundle the name is the weekday(s) alone ("Monday", "Tue/Thu"), or weekday plus start time when the same day runs twice ("Saturday 11:00").
- `complete_cohorts: []` (default) means completeness is unknown. A reviewer may assert a finite course group's entire ordered schedule is recorded using its exact cohort name, or the reserved marker `"__unnamed__"` for sessions with null cohort. Named cohorts cannot use that reserved name. Markers must be unique, refer to existing groups, and each marked group must contain confirmed sessions. Only courses may be marked. This assertion enables #N of total within the selected cohort's full session sequence, including past/filter-excluded dates; bounds, patterns and sparse samples never establish completeness. Omitted markers preserve the assertion; `[]` clears it. When replacing sessions, reviewers must preserve a genuinely complete sequence or explicitly clear the marker.

- Session fields: `date` (required), `cohort`, `start_time`, `end_time`, `timezone`, `location_kind`, `venue_id`, `offsite_name`, `offsite_address`, `offsite_city`, `offsite_lat`, `offsite_lng`. Date/time strings are ISO; time is local wall time. Missing time/timezone keys snapshot listing defaults at replacement time; explicit null means unknown. Later partial updates to listing defaults preserve session snapshots. End time must follow start time on the same local day; overnight sessions are not modeled. Timezone is an IANA name, or null = unconfirmed. No inferred UTC instants/DST resolution.
- Listing `venue_id` is the organizer and default actual venue. `location_kind` is `venue` (existing default), `offsite`, `unknown`, or `multiple`. Offsite has a required name and separate optional address/city/coordinate pair; missing city is visibly unknown. Legacy writes supplying `offsite_name` without location kind select offsite. Explicit location kind wins. Occurrences default to `inherit` (listing location); `venue` requires an actual `venue_id`; `offsite` and `unknown` override it. Cards/pages summarize actual session venues, not the organizing gym. Radius searches use actual confirmed-session locations in the selected date window, or listing location if there are no sessions; unknown coordinates never borrow organizer coordinates.
- `one_off` requires start date (optional end bound); `multi_day` and `course` require ordered start/end dates. Bounds constrain sessions. One-off sessions must be on the start date. One-off/multi-day bounds can be the convenient authoritative event span; course bounds are a term span, not proof of every date within it.
- `recurring` publication requires confirmed occurrences or a structured pattern: `recurrence: "weekly", weekday: 1..7` (Mon–Sun), or `recurrence: "monthly", weekday: 1..7, month_week: 1..5 | -1` (-1 = last). Patterns also work on courses. They describe evidence and **never generate dates or satisfy date filters**. No arbitrary rule engine. `unscheduled` has no dates/times/occurrences; shown only with the reveal toggle, never in date-filtered results.
- `sources` (HTTP(S) evidence links) remain internal. `checked_on` means sources last checked. Code maintains `catalogue_updated_on` only for substantive listing/session changes; source checks, evidence links, legacy prose changes and identical reimports do not refresh it. The public footer shows only **Last updated**, using `catalogue_updated_on`. Legacy null means no established substantive-update date, so the public timestamp is omitted; `checked_on` is never used as a fallback or exposed as provenance. Both dates remain stored internally. No rebuild clock is used.

### Small updates

```elixir
alias ClimbOntario.Catalogue.Import
# Evidence-only partial update: confirmed sessions and catalogue update date survive.
Import.put_listing(%{id: 28, checked_on: ~D[2026-09-17]})
# Explicit clear is validated; a recurring row still needs its structured pattern.
Import.put_listing(%{id: 28}, [])
```

In the weekly refresh you don't call the importer by hand: proposals go through `research/apply.sh`.
