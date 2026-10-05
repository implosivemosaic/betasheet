# Example: a good capture (Hogtown Boulders, 2026-10-05)

The kinds of work, in order:

1. **Homepage → every relevant page.** Open the homepage, list its links, and visit Courses, Youth, Day Camp, Calendar, Pricing. Save each page's text.
2. **Booking calendars.** Courses has three "Book Now" links to Rock Gym Pro. The calendar looks empty until you click a highlighted date.
   - Intro to Bouldering (drop-in): highlighted dates Oct 6–Dec 19 on Tue, Thu, Sat and Sun. One click per weekday gives the times: Tue/Thu 6:30–8 PM, Sat/Sun 3–4:30 PM (from a sample date).
   - Level 1 (multi-week): clicking Tue Oct 13 lists Day #1–#3: Oct 13, 20, 27, 6:30–8:30 PM. One click covers the whole cohort.
   - P.A. Day Camp: no highlighted dates, Oct–Dec. Record that and move on.
3. **Images.** The calendar page has event posters with no text. Save each as a file and label it "saved, not inspected".
4. **Instagram.** Profile → list post links → open each recent post → save the caption, the post date and a screenshot. Find: youth mock comp Mon Oct 5, 5:45–8:30 PM. Open the link-in-bio too.
5. **Facebook.** The Events tab says "No events to show". Save that. Posts don't come through as text, so take a screenshot.
6. **Leads check before leaving.** Everything seen gets a status.

## Index excerpt
| Source | File | What it shows |
|---|---|---|
| hogtownboulders.com/courses | evidence/courses.txt | Intro $47.50, Level 1 $110, Level 2 $150; 3 RGP links |
| RGP Intro bo=414abd… | evidence/rgp-intro-dates.txt, rgp-intro-tue.txt … | Dates Oct 6–Dec 19; Tue/Thu 6:30–8 PM, Sat/Sun 3–4:30 PM (sample dates) |
| RGP Level 1 bo=6b7d01… | evidence/rgp-level1-oct13.txt | Day #1–3: Tue Oct 13/20/27, 6:30–8:30 PM |
| IG post Dd_4AnkhGek (Oct 3) | evidence/ig-Dd_4AnkhGek.md, .jpg | Mock comp Mon Oct 5, 5:45–8:30 PM |
| facebook.com/hogtown.boulders/upcoming_hosted_events | evidence/fb-events.txt | "No events to show" |

## Leads
| Lead | Status |
|---|---|
| RGP P.A. Day Camp | captured: no bookable dates Oct–Dec |
| Youth team schedule | not published by gym: "3 sessions/week", no days or dates |
| Level 2 | captured: advertised 4 weeks, RGP lists 3 days (recorded as-is) |
| Calendar posters (3) | saved, not inspected |
| x.com/hogtownboulders | blocked: HTTP 403 |

## Tool hints
- `agent-browser --session <your batch id> open URL` (default Lightpanda engine; never Chrome on this box, it exhausts memory. Use BrowserClaw `screenshot` when you need a visual), `snapshot -i` (highlighted dates are `link "13"`), `click @eN`, `get text body > file`.
- `lego browser connect --device m3-ghost --port 9013`, then `lego browser call tabs '{"action":"new","url":"URL"}'` → note your page ID → `read '{"page":ID}'`, `screenshot '{"page":ID}' > shot.json` (JSON `data` is base64; decode it to a .jpg), and finally `tabs '{"action":"close","page":ID}'`.
