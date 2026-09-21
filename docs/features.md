# Features

## Discovery (`/`)

- Separate “What are you looking for?” keyword input uses a 300 ms debounce and URL `q` (trimmed, at most 100 characters; malformed/oversized input is ignored). Matching searches titles, descriptions, organizer gym and actual session/offsite venue names. Case/diacritics are normalized; every query word must match a word across those fields. Exact/prefix matches apply to all terms; terms of 4+ characters also allow one insertion, deletion or substitution against a whole word (not transpositions). Short terms have no fuzzy expansion. Matching only filters candidates: chronological ordering is never replaced by relevance. Keyword changes/removal reset depth; Load more and detail/back preserve it.
- Location prompt: city, town or postal code, with typeahead of Ontario places. Not a gate; the page shows upcoming listings province-wide until a place is entered.
- "Use my location" maps device coordinates to the nearest known place.
- Labelled Location controls combine city/postal search with a distance selector (40 km default); changing distance preserves the other criteria.
- Compact Event type, When and Audience controls share one row, with selected counts/time visible. Each opens a native modal bottom sheet on mobile (centered dialog on desktop). Apply commits that group's choices to the URL and resets pagination; Cancel, Close or Escape discard pending choices. Native modal focus trapping and restoration keep keyboard navigation contained. Active chips remain outside the dialogs. Audience includes kids & youth, adults, families, adaptive, women and LGBTQ+ (internal tag `queer`; organizer text remains untouched).
- Active filters immediately above results show individually removable location/distance, keyword, types, nondefault time and audiences, plus Clear all. Defaults have no empty row. Every control/removal resets pagination; URL state and detail/back context remain intact.
- Results: "Coming up" sorted chronologically across all kinds, including recurring listings with upcoming confirmed sessions under Anytime. In-progress courses use their next confirmed session when known. Recurring listings without future confirmed dates stay in the separate "Ongoing & recurring" section. When offers optional inclusive From/To bounds plus Mon–Sun checkboxes. Selected weekdays are OR; range and weekdays are AND. This weekend/Next 7 days fill the pending range fields; Apply commits one explicit state (`from`, `to`, `days`), Cancel/Escape discard it. Range and weekdays have separate removable active chips. Invalid or reversed URL ranges reset both bounds; invalid weekdays are ignored. Legacy `when` URLs normalize to explicit ranges. Discovery remains upcoming-only: lower bounds earlier than today are clamped to today, and wholly historical ranges return no dated results. Courses/recurring listings match confirmed sessions across the entire series, never speculative pattern dates; gaps do not match. One-off/multiday events without session rows use the actual known interval and weekday intersection (at most seven arithmetic candidates). Date/weekday and distance must match the same session; sort/datebox use the earliest qualifying date. Unscheduled programs are excluded from discovery; legacy `unscheduled=1` is ignored/dropped. Their data and detail pages remain intact. Recurring listings retain their existing separate/date-based behavior.
- Initial results render at most 20 cards across both sections combined. Explicit **Load more** adds 20; the shown/total count includes both dated and undated listings. Filter/location changes reset the batch. Loaded depth lives in the validated `page` URL parameter (1–50); returning from detail via the existing All listings/history mechanism restores it. No infinite scroll or CSS-hidden results.
- Cards show code-owned kind badge, title, actual venue/city and distance, generated dates/pattern, summary, ages, Tentative tag, no relative-day hints. Missing venue/city/time/timezone is explicit; prose schedule notes are not rendered.

## Private preview interest

“Get updates like these” inherits location, radius, kinds and audience into an editable email/consent form. It saves interest only: updates are not sending yet, and confirmation says no emails sent. Capture is disabled in dev pending coordinator activation; no subscriptions, email integration or address listing/export exists.

## Event page (`/e/<id>-<slug>`)

- Permanent URL keyed by research event id; stale slugs redirect; unpublished rows 404.
- One surface: title, short summary, then When (pattern and span), Where (name, address, map) and Who; a caveat only when our own date, time or place is uncertain; a full-width "View original event" button; only "Last updated" at the foot, using the substantive catalogue-update date. Legacy rows without that date omit the timestamp; evidence dates stay internal. Price, rules and booking conditions are the organizer's to show.
- "Share" sits in the page header so it clearly shares our page, not the organizer's. "All listings" returns to the search you came from.
- One prominent link labelled by what it is: "Register with organizer", "View official event", or "Gym website". "Copy link" copies the URL (native share sheet on phones).
- Open Graph and Twitter meta tags for link previews. Past listings show a notice.
- Source URLs stay internal. Named cohorts share one listing; confirmed sessions sit in a collapsed disclosure, showing local dates/times and differing actual venues/timezones without repeating common place/timezone details. Unknown cohort dates are explicit; recurrence patterns never invent occurrences.

## Data

- 54 venues. 311 research events: currently 302 published and 9 held. Interest capture does not change catalogue or research data.
- Bundled OpenCage geo: 54 gym coordinates (15 approximate), 524 Ontario FSAs, 418 reviewed place names. Eleven rejected inputs are excluded and do not fall through to prefix matches. Public source credits: `/location-data`. Approximate gym Map links use the organizer street address, not a centroid pin.
