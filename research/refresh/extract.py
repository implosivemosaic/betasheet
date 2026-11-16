"""Turn a saved capture into a comparable record.

One pure function per source type, no I/O beyond reading the capture it is given and the
rendered text saved beside it. The output is what `compare.py` diffs and hashes, and it is
deliberately smaller than the capture: raw page text carries clocks, counters and adverts,
none of which are content.

The capture contract (see `betasheet-data/betasheet/runs/2026-11-15-link-audit/../..`,
`wren-tools/compare-contract/CONTRACT.md`) splits two questions that used to be one:

  outcome   did the tool actually read the source?   read | read-empty | partial | failed
  verdict   what changed since the baseline?         compare.py

A record therefore carries `outcome` and `coverage` beside its `entries`, and
`compare.py` refuses to compare anything that is not `read` or `read-empty`.

Wave/weave: imported by compare.py and the refresh tools. Never writes.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from datetime import date, datetime

READ, READ_EMPTY, PARTIAL, FAILED = "read", "read-empty", "partial", "failed"
BASELINE_OUTCOMES = (READ, READ_EMPTY)

MONTHS = {name: i + 1 for i, name in enumerate(
    "January February March April May June July August September October "
    "November December".split())}
ABBREV = {name[:3]: num for name, num in MONTHS.items()}
ABBREV.update({"Sept": 9})

# Rock Gym Pro puts one of three line kinds in `series[].days` / `months[].clicks[].days`.
NO_TIMES = "sorry, but there are no available times for"
COURSE_LABEL = re.compile(r"^Day\s*#\d+:\s*", re.I)
DAY_LINE = re.compile(
    r"^[A-Za-z]{3,9},?\s+([A-Za-z]{3,9})\s+(\d{1,2})(?:,\s*(\d{4}))?\s*(.*)$")
TIME_RANGE = re.compile(
    r"(\d{1,2})(?::(\d{2}))?\s*([AP])\.?M\.?\s*(?:to|-|–)\s*"
    r"(\d{1,2})(?::(\d{2}))?\s*([AP])\.?M\.?", re.I)

# Shells, and notices that are evidence but not a calendar. Exact phrases only: a generic
# token rejects real pages. Measured over the November corpus, `not found` appears in Hub's
# marketing copy (7 pages) and `recaptcha` in a footer notice (14 pages), while every exact
# phrase below matches only a shell. `oops, this page not found` is a soft 404 served
# inside full site chrome, so body length cannot be a requirement for a phrase this specific.
SHELL_PHRASES = {
    "security-verification": "performing security verification",
    "javascript-required": "you need to enable javascript to run this app",
    "checking-browser": "checking your browser",
    "verify-human": "verify you are human",
    "page-not-found": "error: page not found",
    "page-not-found-soft": "we couldn't find the page you were looking for",
    "page-not-found-oops": "oops, this page not found",
    "page-not-found-missing": "the page you looking for doesn't exist",
    "page-not-found-server": "the resource requested could not be found on this server",
}
# A readable status notice. The source answered: the offering is withdrawn, moved or
# empty. That is evidence for a reviewer and it is not a capture gap, but it is also not
# a successful calendar read, so it cannot become a baseline.
NOTICE_PHRASES = {
    "plan-inactive": "this plan is inactive",
    "nothing-here": "there is nothing here",
    "file-deleted": "a été supprimé",
    "file-deleted-en": "the file you requested has been deleted",
}
# A document that is nothing but a 404 heading and a way home.
BARE_404 = re.compile(r"^404\s+not found\s+return home$", re.I)
GRID_HEADER = re.compile(r"\bMo\b\s*\bTu\b\s*\bWe\b")


def _text(value):
    return (value or "").replace("\xa0", " ")


def _lines(text):
    return len([line for line in text.splitlines() if line.strip()])


def _iso(value):
    """A date or datetime, normalised to an ISO date string, or None."""
    if not value:
        return None
    if isinstance(value, date):
        return value.isoformat()
    raw = str(value).strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(raw).date().isoformat()
    except ValueError:
        return raw[:10] if re.match(r"^\d{4}-\d{2}-\d{2}", raw) else None


def _clock(hour, minute, meridiem):
    hour = int(hour) % 12
    if meridiem.upper().startswith("P"):
        hour += 12
    return f"{hour:02d}:{int(minute or 0):02d}"


def _month_number(name):
    name = (name or "").strip().rstrip(".")
    if not name:
        return None
    title = name[:1].upper() + name[1:].lower()
    return MONTHS.get(title) or ABBREV.get(name[:4].capitalize()) or ABBREV.get(name[:3].capitalize())


def _window_months(titles):
    """[(year, month)] from month titles like 'November 2026'."""
    out = []
    for title in titles:
        match = re.match(r"([A-Za-z]+)\s+(\d{4})", _text(title).strip())
        if match:
            number = _month_number(match.group(1))
            if number:
                out.append((int(match.group(2)), number))
    return out


def _resolve_year(month, explicit, window):
    """Year for a month, from the capture's own month titles.

    A repeated month in the window (December 2026 and December 2027) is genuinely
    ambiguous, so the year stays None and the entry is never used for a removal claim.
    """
    if explicit:
        return int(explicit), "line"
    years = sorted({year for year, number in window if number == month})
    if len(years) == 1:
        return years[0], "month-title"
    return None, "ambiguous"


def _session_entries(days, window, cohort=None):
    """Classify `days[]` lines into dated entries, and keep the rest as errors."""
    entries, errors = [], []
    for raw in days:
        line = _text(raw).strip()
        if not line:
            continue
        low = line.lower()
        if low.startswith(NO_TIMES):
            errors.append({"reason": "no-available-times", "line": line,
                           "clicked_date": _clicked_date(line)})
            continue
        body = COURSE_LABEL.sub("", line)
        match = DAY_LINE.match(body)
        if not match:
            errors.append({"reason": "unparsed", "line": line})
            continue
        month = _month_number(match.group(1))
        if not month:
            errors.append({"reason": "unparsed", "line": line})
            continue
        year, source = _resolve_year(month, match.group(3), window)
        day = int(match.group(2))
        try:
            when = date(year, month, day) if year else None
        except ValueError:
            errors.append({"reason": "invalid-date", "line": line})
            continue
        times = TIME_RANGE.search(body)
        start = end = None
        if times:
            start = _clock(times.group(1), times.group(2), times.group(3))
            end = _clock(times.group(4), times.group(5), times.group(6))
        entries.append({
            "date": when.isoformat() if when else None,
            "start": start, "end": end, "state": "available", "cohort": cohort,
            "year_source": source, "year_inferred": when is None,
            # `line` is the comparable text with the course label removed; the label
            # renumbers as dates elapse and is kept only as `raw` evidence.
            "line": body.strip(), "raw": line,
        })
    return entries, errors


def _clicked_date(line):
    match = re.search(r"for\s+[A-Za-z]{3,9},?\s+([A-Za-z]+)\s+(\d{1,2})", line)
    if not match:
        return None
    month = _month_number(match.group(1))
    if not month:
        return None
    return {"month": month, "day": int(match.group(2))}


def _dedupe(entries):
    """One entry per (date, start, end, cohort); identical repeats carry no information."""
    seen, out = set(), []
    for entry in entries:
        key = (entry["date"], entry["start"], entry["end"], entry["cohort"], entry["state"])
        if key in seen:
            continue
        seen.add(key)
        out.append(entry)
    return sorted(out, key=lambda e: (e["date"] or "", e["start"] or "", e["state"]))


def _coverage(contract, requested, read, window, inspected, errors,
              challenge=None, recovered=False):
    first = last = None
    if window:
        ordered = sorted(window)
        first = f"{ordered[0][0]:04d}-{ordered[0][1]:02d}"
        last = f"{ordered[-1][0]:04d}-{ordered[-1][1]:02d}"
    complete = bool(read) and (requested is None or read >= requested)
    return {"contract": contract, "months_requested": requested, "months_read": read,
            "window": {"first": first, "last": last},
            "inspected": inspected, "challenge_detected": challenge,
            "complete": complete, "errors": errors, "recovered": recovered}


# --------------------------------------------------------------------------- Rock Gym Pro

def extract_rockgympro(path, rendered_text=None):
    """Read a `*.rgp.json` capture. `rendered_text` is the sibling `.rgp.txt` when saved."""
    data = json.load(open(path))
    months = data.get("months") or []
    titles = [m.get("title") for m in months if m.get("title")]
    window = _window_months(titles)
    declared = data.get("coverage") if isinstance(data.get("coverage"), dict) else {}

    days = [line for series in data.get("series") or []
            for line in series.get("days") or []]
    for month in months:
        for click in month.get("clicks") or []:
            days.extend(click.get("days") or [])
    entries, errors = _session_entries(days, window)
    entries = _dedupe(entries)

    available = [day for month in months for day in month.get("available") or []]
    clicks = sum(len(month.get("clicks") or []) for month in months)
    inspected = declared.get("inspected") or {}
    cells = sum(len(month.get("cells") or []) for month in months)
    declared_cells = sum(int(m.get("cells_parsed") or 0)
                         for m in (inspected.get("months") or []) if isinstance(m, dict))
    cells = max(cells, declared_cells)
    if not cells and entries:
        cells = len(entries)

    if not months:
        outcome, evidence = FAILED, None
        notes = ["no calendar months were read"]
    elif entries:
        outcome, evidence = READ, None
        notes = []
    elif available or clicks:
        # The grid offered days and every click came back with no times. Rendered, but
        # it says nothing about days that were never clicked.
        outcome, evidence = READ, "clicked-no-times"
        notes = ["clicked %d day(s); none had an available time" % max(clicks, 1)]
    else:
        grid_seen = bool(GRID_HEADER.search(rendered_text or "")) or cells > 0
        outcome = READ_EMPTY if grid_seen else FAILED
        evidence = "zero-available-days" if grid_seen else None
        notes = (["rendered calendar with no available day"]
                 if grid_seen else ["month titles without evidence the grid was read"])

    requested = declared.get("months_requested")
    if requested is not None and len(months) < requested and outcome == READ:
        outcome = PARTIAL
        notes.append("read %d of %d requested months" % (len(months), requested))

    return {
        "source_id": data.get("id"), "type": "rockgympro",
        "captured_at": data.get("captured_at"), "outcome": outcome, "evidence": evidence,
        "challenge": None,
        "coverage": _coverage("calendar-3-months", requested, len(months), window,
                              inspected, [e["reason"] for e in errors],
                              recovered=not declared),
        "window": {"months": [f"{y:04d}-{m:02d}" for y, m in window],
                   "read": len(months)},
        "entries": entries, "errors": errors, "cells": None, "notes": notes,
        "path": os.path.basename(path),
    }


# ------------------------------------------------------------------------------ Redpoint

def extract_redpoint(path, rendered_text=None):
    """Read a `*.rphq.json` capture (PrimeVue datepicker cells and clicked details).

    `rendered_text` is the sibling `.rphq.txt`. When a capture has no cells it is the
    only thing that can tell a gap from the portal saying why there is none: an
    error-month capture whose page reads "This plan is inactive" is a notice, not a
    failed render, and the same JSON shape therefore has two outcomes.
    """
    data = json.load(open(path))
    months = data.get("months") or []
    declared = data.get("coverage") if isinstance(data.get("coverage"), dict) else {}

    cells, titles, states = [], [], []
    for month in months:
        if not isinstance(month, dict) or "cells" not in month:
            continue
        cells.extend(month.get("cells") or [])
        if month.get("title"):
            titles.append(month["title"])
        states.extend(month.get("available") or [])
    window = _window_months(titles)

    entries, errors = [], []
    for label in dict.fromkeys(states):
        text = _text(label).strip()
        match = re.match(r"([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})\s*,?\s*(.*)$", text)
        if not match:
            errors.append({"reason": "unparsed", "line": text})
            continue
        month = _month_number(match.group(1))
        if not month:
            errors.append({"reason": "unparsed", "line": text})
            continue
        suffix = match.group(4).strip().lower()
        state = "available" if suffix.startswith("available") else suffix or "unknown"
        try:
            when = date(int(match.group(3)), month, int(match.group(2)))
        except ValueError:
            errors.append({"reason": "invalid-date", "line": text})
            continue
        entries.append({"date": when.isoformat(), "start": None, "end": None,
                        "state": state, "cohort": None, "year_source": "line",
                        "year_inferred": False, "line": text})
    entries = _dedupe(entries)

    if not cells:
        kind, signature = page_signature(rendered_text or "")
        outcome, evidence = FAILED, None
        notice = signature if kind == "notice" else None
        challenge = signature if kind == "unreadable" else None
        notes = (["notice: %s" % signature] if kind == "notice" else
                 ["unreadable: %s" % signature] if kind == "unreadable" else
                 ["no calendar cells; page is not an offering calendar"])
    else:
        notice = challenge = None
        if entries:
            outcome, evidence, notes = READ, None, []
        else:
            outcome, evidence = READ_EMPTY, "zero-available-days"
            notes = ["rendered calendar with no available date"]

    counts = {"available": 0, "waitlist": 0, "full": 0, "unmarked": 0}
    for cell in cells:
        label = _text(cell.get("label")).lower()
        for word in ("available", "waitlist", "full/closed", "unmarked"):
            if word == "unmarked" and not label.endswith(("available", "waitlist", "full/closed")):
                counts["unmarked"] += 1
                break
            if label.endswith(word):
                counts[{"full/closed": "full"}.get(word, word)] += 1
                break

    requested = declared.get("months_requested")
    read = len([m for m in months if isinstance(m, dict) and "cells" in m])
    if requested is not None and read < requested and outcome == READ:
        outcome = PARTIAL
        notes.append("read %d of %d requested months" % (read, requested))

    return {
        "source_id": data.get("id"), "type": "redpoint",
        "captured_at": data.get("captured_at"), "outcome": outcome, "evidence": evidence,
        "challenge": challenge,
        "notice": notice,
        "coverage": _coverage("calendar-3-months", requested, read, window,
                              declared.get("inspected") or {}, [],
                              recovered=not declared),
        "window": {"months": [f"{y:04d}-{m:02d}" for y, m in window], "read": read},
        "entries": entries, "errors": errors, "cells": counts, "notes": notes,
        "path": os.path.basename(path),
    }


# ---------------------------------------------------------------------------------- page

def page_signature(text):
    """What this document *is*, as `(kind, signature)`; `(None, None)` for a page.

    `kind` is `unreadable` when nothing on it can be read as the source (a challenge, a
    JavaScript shell, a hard 404, a navigation-only render) and `notice` when the source
    answered with a status — the programme is inactive, the file is deleted, the
    offering is empty. Both refuse to become a baseline; only the notice is evidence a
    reviewer should see.
    """
    low = _text(text).lower()
    if BARE_404.match(" ".join(low.split())):
        return "unreadable", "hard-404"
    for signature, phrase in SHELL_PHRASES.items():
        if phrase in low:
            return "unreadable", signature
    for signature, phrase in NOTICE_PHRASES.items():
        if phrase in low:
            return "notice", signature
    return None, None


def extract_page(meta_path, text_path=None):
    """Read a saved page capture (`*.meta.json` beside `*.norm.txt`)."""
    meta = json.load(open(meta_path))
    if text_path is None:
        text_path = meta_path.replace(".meta.json", ".norm.txt")
    text = open(text_path, errors="replace").read() if os.path.exists(text_path) else ""
    lines = meta.get("text_lines")
    if lines is None:
        lines = _lines(text)
    kind, signature = page_signature(text)
    # A capture that recorded its own classification must agree with the evidence it
    # saved. Disagreement is a finding, not something to resolve silently.
    declared = meta.get("coverage") if isinstance(meta.get("coverage"), dict) else {}
    declared_shell = declared.get("challenge_detected")
    declared_notice = declared.get("notice")
    disagreement = []
    if declared_shell and declared_shell != (signature if kind == "unreadable" else None):
        disagreement.append("declared challenge %r, evidence %r" % (declared_shell, signature))
    if declared_notice and declared_notice != (signature if kind == "notice" else None):
        disagreement.append("declared notice %r, evidence %r" % (declared_notice, signature))

    if kind:
        outcome = FAILED
        reason = kind
        notes = ["%s: %s" % (kind, signature)]
    elif not text.strip():
        outcome, reason, signature = FAILED, "unreadable", "empty-body"
        notes = ["empty render"]
    elif lines < 4:
        outcome, reason = FAILED, "unreadable"
        notes = ["render of %d lines" % lines]
    else:
        outcome, reason, notes = READ, None, []

    digest = hashlib.sha256(" ".join(_text(text).split()).encode()).hexdigest()
    return {
        "source_id": meta.get("id"), "type": "page",
        "captured_at": meta.get("captured_at"), "outcome": outcome, "evidence": None,
        "challenge": signature if reason == "unreadable" else None,
        "notice": signature if reason == "notice" else None,
        "coverage": _coverage("web-page", 1, 1 if outcome == READ else 0, [], {},
                              [signature] if signature else [],
                              signature if reason == "unreadable" else None,
                              recovered=True),
        "window": {"months": [], "read": 0},
        "entries": [{"date": None, "start": None, "end": None, "state": "content",
                     "cohort": None, "text_sha": digest, "lines": lines}],
        "errors": [], "cells": None, "notes": notes + disagreement,
        "url": meta.get("final_url") or meta.get("requested_url"),
        "path": os.path.basename(meta_path),
    }


# -------------------------------------------------------------------------------- social

IG_PERMALINK = re.compile(r"instagram\.com/(?:[^/\s]+/)?(?:p|reel)/([A-Za-z0-9_-]+)")
FB_POST_ID = re.compile(r"(?:set=pcb\.|story_fbid=)(\d{6,})")
FB_PHOTO_ID = re.compile(r"[?&]fbid=(\d{6,})")
ISO_DATE = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
LONG_DATE = re.compile(r"\b(January|February|March|April|May|June|July|August|September|"
                       r"October|November|December)\s+(\d{1,2}),?\s+(\d{4})\b")


def _social_sha(text):
    return hashlib.sha256(" ".join(_text(text).split()).encode()).hexdigest()


def extract_instagram(path):
    """Read an `ig-*.md` capture. Identity is the post shortcode, never the caption."""
    text = open(path, errors="replace").read()
    posts, seen = [], set()
    for line in text.splitlines():
        # Profile captures list permalinks as bullets; single-post captures put the
        # permalink in a heading. Both are the same identity.
        match = IG_PERMALINK.search(line)
        if not match or match.group(1) in seen:
            continue
        seen.add(match.group(1))
        published = ISO_DATE.search(line)
        if not published:
            long_form = LONG_DATE.search(line)
            if long_form:
                published = type("M", (), {"group": lambda self, i: (
                    "%s-%02d-%02d" % (long_form.group(3), MONTHS[long_form.group(1)],
                                      int(long_form.group(2))) if i == 1 else None)})()
        posts.append({"id": match.group(1), "url": "https://www.instagram.com/p/%s/" % match.group(1),
                      "published": published.group(1) if published else None,
                      "text_sha": None, "alts_sha": None, "kind": "post"})
    body = text.split("## newest post text", 1)[-1].split("##", 1)[0]
    if posts and body.strip():
        posts[0]["text_sha"] = _social_sha(body)

    stopping = posts[-1]["id"] if posts else None
    named = "newest post:" in text.lower()
    outcome = READ if posts else (PARTIAL if named else FAILED)
    return {
        "source_id": os.path.basename(path)[:-3], "type": "instagram",
        "captured_at": _capture_stamp(text), "outcome": outcome,
        "evidence": None, "challenge": None,
        "coverage": _coverage("social-window", 4, len(posts), [], {},
                              [] if posts else (["no permalink read"] if named
                                                else ["no posts read"]), recovered=True),
        "window": {"months": [], "read": 0},
        "posts": posts, "entries": [],
        "errors": [], "cells": None, "notes": [],
        "coverage_social": {"anchor_id": None, "anchor_reached": None,
                            "fully_read": [p["id"] for p in posts],
                            "stopping_post": stopping, "stopped_reason": "declared-limit"},
        "path": os.path.basename(path),
    }


def extract_facebook(path):
    """Read an `fb-*.md` capture. Post ids and photo ids stay distinct."""
    text = open(path, errors="replace").read()
    posts, seen = [], set()
    for token in FB_POST_ID.findall(text):
        if token not in seen:
            seen.add(token)
            posts.append({"id": token, "kind": "post", "published": None,
                          "text_sha": None, "alts_sha": None})
    for token in FB_PHOTO_ID.findall(text):
        if token not in seen:
            seen.add(token)
            posts.append({"id": token, "kind": "photo", "published": None,
                          "text_sha": None, "alts_sha": None})
    if not posts:
        bodies = [line[2:].strip() for line in text.splitlines()
                  if line.startswith("- ") and len(line) > 30]
        for index, body in enumerate(bodies):
            match = LONG_DATE.search(body)
            posts.append({"id": None, "kind": "post", "published":
                          ("%s-%02d-%02d" % (match.group(3), MONTHS[match.group(1)],
                                             int(match.group(2)))) if match else None,
                          "text_sha": _social_sha(body), "alts_sha": None,
                          "ordinal": index})
    return {
        "source_id": os.path.basename(path)[:-3], "type": "facebook",
        "captured_at": _capture_stamp(text),
        "outcome": READ if posts else FAILED,
        "evidence": None, "challenge": None,
        "coverage": _coverage("social-window", 6, len(posts), [], {},
                              [] if posts else ["no posts read"], recovered=True),
        "window": {"months": [], "read": 0},
        "posts": posts, "entries": [],
        "errors": [], "cells": None, "notes": [],
        "coverage_social": {"anchor_id": None, "anchor_reached": None,
                            "fully_read": [p["id"] for p in posts if p["id"]],
                            "stopping_post": next((p["id"] for p in reversed(posts) if p["id"]), None),
                            "stopped_reason": "declared-limit"},
        "path": os.path.basename(path),
    }


def _capture_stamp(text):
    match = re.search(r"captured_at:?\s*([0-9T:\-+Z]+)", text)
    return match.group(1) if match else None


# ------------------------------------------------------------------------------ dispatch

def extract(path):
    """Pick the extractor from the capture's own filename."""
    name = str(path)
    if name.endswith(".rgp.json"):
        text_path = name.replace(".rgp.json", ".rgp.txt")
        rendered = open(text_path, errors="replace").read() if os.path.exists(text_path) else ""
        return extract_rockgympro(name, rendered_text=rendered)
    if name.endswith(".rphq.json"):
        text_path = name.replace(".rphq.json", ".rphq.txt")
        rendered = open(text_path, errors="replace").read() if os.path.exists(text_path) else ""
        return extract_redpoint(name, rendered_text=rendered)
    if name.endswith(".meta.json"):
        return extract_page(name)
    if os.path.basename(name).startswith("ig-") and name.endswith(".md"):
        return extract_instagram(name)
    if os.path.basename(name).startswith("fb-") and name.endswith(".md"):
        return extract_facebook(name)
    raise ValueError("unknown capture kind: %s" % name)


if __name__ == "__main__":
    import sys
    for target in sys.argv[1:]:
        record = extract(target)
        print(json.dumps({k: record[k] for k in
                          ("source_id", "type", "outcome", "evidence", "challenge")}, indent=1))
