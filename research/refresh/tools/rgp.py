#!/usr/bin/env python3
"""Capture a Rock Gym Pro offering calendar as structured JSON with agent-browser.

Usage: tools/rgp.py <session> <out-dir> <id> <url> [months]

Read-only: opens the offering, walks forward month by month, clicks each highlighted
date and records the session series it reveals. Saves `<id>.rgp.json` and `<id>.rgp.txt`
(the rendered text) into out-dir.

Every highlighted date is accounted for exactly once. A date either shows a session, or
answers "no available times", or is recorded as unread after one retry — a footer where the
session list should be is a gap in the evidence, not an absence of sessions. The capture
also states which months it read and refuses to call a duplicated or skipped month
complete, because counting panels is not coverage.
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys

import coverage
from extract import page_signature

session, out_dir, ident, url = sys.argv[1:5]
months = int(sys.argv[5]) if len(sys.argv) > 5 else 6
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)

LOAD_TIMEOUT = "waiting for load state"
# A session line, or the widget's own "nothing here" message. Anything else after the
# selected date — the portal footer, a cookie banner — is chrome, not an answer.
NO_TIMES = "no available times"
SESSION_LINE = re.compile(r"(Day\s*#\d+|\d{1,2}(?::\d{2})?\s*[AP]\.?M\.?)", re.I)
STOP_LINE = re.compile(r"^(Availability|\d+\s+spaces?|Date Selected)", re.I)


def ab(*args):
    result = subprocess.run(["agent-browser", "--session", session, *args],
                            capture_output=True, text=True, timeout=120)
    if result.returncode != 0:
        raise RuntimeError("agent-browser %s failed: %s" % (args[0], result.stderr.strip()))
    return result.stdout.strip()


def js(expr):
    raw = ab("eval", expr)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def open_url(url, ready, polls=12):
    """Navigate, then wait for the widget rather than for the page's `load` event.

    A booking widget streams its calendar, so the browser's load state can time out
    while the DOM is perfectly usable. That is a navigation detail, not a failed
    capture: poll the widget and let the coverage block say what was actually read.
    """
    note = None
    try:
        ab("open", url)
    except RuntimeError as exc:
        if LOAD_TIMEOUT not in str(exc):
            raise
        note = "navigation load-state timed out; polled the DOM instead"
    for _ in range(polls):
        if ready():
            return note
        ab("wait", "1000")
    return note or "widget never rendered"


def month_state():
    return js("""(() => {
      const cal = document.querySelector('.ui-datepicker-calendar');
      const title = document.querySelector('.ui-datepicker-group .ui-datepicker-title, .ui-datepicker-title');
      if (!cal || !title) return null;
      const cells = [...cal.querySelectorAll('td')].map(td => ({
        day: td.textContent.trim(),
        cls: td.className,
        y: td.dataset.year || null,
        m: td.dataset.month || null,
        cur: td.classList.contains('ui-datepicker-current-day'),
      }));
      const headers = [...cal.querySelectorAll('thead th')].map(th => th.textContent.trim());
      // Every *day* cell the widget paints carries one of these two classes, always:
      // measured on the live widget at 12s and 15s, available and unavailable alike. So a
      // day cell with neither has not been painted yet, and its availability is unknown
      // rather than empty — the difference between "no sessions" and "not read".
      //
      // The grid pads itself to 35 or 42 cells with `ui-datepicker-other-month` cells that
      // hold no day number and never get a paint class. They belong to another month and
      // are not evidence about this one, so they are excluded rather than counted unread.
      const dayCells = cells.filter(c => /^\d{1,2}$/.test(c.day));
      const unpainted = dayCells.filter(c =>
        !c.cls.includes('datepicker-available-day') &&
        !c.cls.includes('datepicker-unavailable-day'));
      return {
        title: title.innerText.trim(),
        cells_parsed: dayCells.length,
        padding_cells: cells.length - dayCells.length,
        unpainted: unpainted.length,
        headers: headers,
        available: cells.filter(c => c.cls.includes('datepicker-available-day')),
        current: cells.filter(c => c.cur).map(c => c.day + ' ' + (c.cls.includes('datepicker-available-day') ? 'available' : 'unavailable')),
        next_disabled: !!document.querySelector('a.ui-datepicker-next.ui-state-disabled'),
      };
    })()""")


def wait_panel(polls=12):
    """Wait for a panel whose day cells are all painted.

    The widget renders its table first and classes each day afterwards, so an early read
    returns a full grid with nothing highlighted — which is indistinguishable from a
    month with no sessions, and would report a live session as removed. Poll until every
    cell carries a paint class, and record the count if it never does.
    """
    state = None
    for _ in range(polls):
        state = month_state()
        if state and state.get("cells_parsed", 0) > 10 and not state.get("unpainted"):
            return state
        ab("wait", "800")
    return state


def click_day(day):
    return js(f"""(() => {{
      const cal = document.querySelector('.ui-datepicker-calendar');
      const td = [...cal.querySelectorAll('td')].find(td => td.textContent.trim() === '{day}'
        && td.classList.contains('datepicker-available-day'));
      if (!td) return false;
      const a = td.querySelector('a') || td;
      a.click();
      return true;
    }})()""")


def details():
    """The selected date, and only the lines that answer it.

    The widget prints the chosen date, then the session list, then whatever else the
    page carries. Keeping only session-shaped lines is what separates "this date has no
    session" from "the detail never arrived": a footer is neither.
    """
    txt = (js("document.body.innerText") or "").replace("\u00a0", " ")
    lines = [re.sub(r"\s+", " ", line).strip() for line in txt.splitlines() if line.strip()]
    try:
        index = next(n for n, line in enumerate(lines) if line.startswith("Date Selected"))
    except StopIteration:
        return {"date_selected": None, "days": []}
    selected = lines[index]
    days = []
    for line in lines[index + 1:index + 40]:
        if STOP_LINE.match(line):
            break
        if NO_TIMES in line.lower() or SESSION_LINE.search(line):
            # The widget prints the booking state on the session's own line, so it is
            # trimmed off here rather than carried into the comparable content.
            days.append(re.sub(r"\s+(Availability|Waitlist|Full/Closed)\s*$", "", line))
    return {"date_selected": selected, "days": days}


def settle(day):
    """Click a highlighted date and wait for its detail; retry once.

    The first click after a page load competes with the widget's own first AJAX call, so
    one retry is cheap insurance against recording a real session as absent. After that
    the date is reported as unread rather than guessed at.
    """
    for attempt in range(2):
        if not click_day(day):
            return {"date_selected": None, "days": []}, "not-clickable"
        detail = {"date_selected": None, "days": []}
        for _ in range(10):
            ab("wait", "500")
            detail = details()
            if detail.get("days"):
                return detail, "settled"
        if attempt == 0:
            ab("wait", "1000")
    return detail, "unread"


note = open_url(url, lambda: bool(wait_panel(3)))
captured = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
result = {"id": ident, "url": url, "captured_at": captured, "months": [], "series": []}
accounting = {"highlighted": 0, "clicked": 0, "read": 0, "no_available_times": 0,
              "unread": 0, "unread_dates": []}
seen = set()
for _ in range(months):
    state = wait_panel()
    if not state:
        break
    entry = {"title": state["title"],
             "cells_parsed": state.get("cells_parsed", 0),
             "padding_cells": state.get("padding_cells", 0),
             "unpainted": state.get("unpainted", 0),
             "headers": state.get("headers") or [],
             "available": [cell["day"] for cell in state["available"]],
             "clicks": []}
    for cell in state["available"]:
        accounting["highlighted"] += 1
        detail, status = settle(cell["day"])
        if status == "not-clickable":
            accounting["unread"] += 1
            accounting["unread_dates"].append({"day": cell["day"],
                                               "date_selected": None,
                                               "reason": "highlighted but not clickable"})
            continue
        accounting["clicked"] += 1
        entry["clicks"].append(detail)
        if status == "unread":
            accounting["unread"] += 1
            accounting["unread_dates"].append({"day": cell["day"],
                                               "date_selected": detail.get("date_selected"),
                                               "reason": "no session detail after retry"})
        elif any(NO_TIMES in line.lower() for line in detail["days"]):
            accounting["no_available_times"] += 1
        else:
            accounting["read"] += 1
        key = json.dumps(detail, sort_keys=True)
        if key not in seen:
            seen.add(key)
            result["series"].append(detail)
    result["months"].append(entry)
    if state.get("next_disabled"):
        break
    js("(() => { const a=document.querySelector('a.ui-datepicker-next'); if(a) a.click(); return true; })()")
    ab("wait", "900")

result["notes"] = [note] if note else []
if result["months"]:
    result["coverage"] = coverage.calendar(months, result["months"], days=accounting)
else:
    # No panel was read, so there is no month sequence to declare: what this capture
    # knows about is the page. Writing a calendar block here would state a problem with
    # a window that never existed, and stop the page baseline being set at all.
    rendered = js("document.body.innerText") or ""
    lines = len([line for line in rendered.splitlines() if line.strip()])
    kind, signature = page_signature(rendered)
    result["coverage"] = coverage.page(
        lines,
        challenge=signature if kind == "unreadable" else None,
        notice=signature if kind == "notice" else None)
unpainted = sum(month.get("unpainted") or 0 for month in result["months"])
if unpainted:
    result["notes"].append("%d day cell(s) were never painted; their availability is "
                           "unknown, not empty" % unpainted)
result["days"] = accounting

raw = js("document.body.innerText") or ""
(out / (ident + ".rgp.txt")).write_text(raw)
(out / (ident + ".rgp.json")).write_text(json.dumps(result, indent=1) + "\n")
block = result["coverage"]
if not result["months"]:
    print("%s: no calendar panel; %s baseline, %d lines, %s" % (
        ident, block["contract"], block.get("inspected", {}).get("lines", 0),
        "complete" if block["complete"] else "NOT COMPLETE"))
else:
    print("%s: %d panels %s, %d highlighted, %d read, %d no-times, %d unread%s" % (
        ident, block["months_read"], block.get("months_observed"),
        accounting["highlighted"], accounting["read"], accounting["no_available_times"],
        accounting["unread"],
        "" if block["complete"] else
        " | NOT COMPLETE: " + "; ".join(block.get("problems") or [])))
