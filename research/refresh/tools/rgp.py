#!/usr/bin/env python3
"""Capture a Rock Gym Pro offering calendar as structured JSON with agent-browser.

Usage: tools/rgp.py <session> <out-dir> <id> <url> [months]

Read-only: opens the offering, walks forward month by month, clicks each highlighted
date and records the session series it reveals. Saves `<id>.rgp.json` and `<id>.rgp.txt`
(the rendered text) into out-dir.

The JSON now states its own coverage: months requested and read, and per month the
populated grid — cell count and header row — so "rendered with no available day" is
something the capture proves rather than something a later reader infers from an empty
array.
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys

import coverage

session, out_dir, ident, url = sys.argv[1:5]
months = int(sys.argv[5]) if len(sys.argv) > 5 else 6
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)


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
      return {
        title: title.innerText.trim(),
        cells_parsed: cells.length,
        headers: headers,
        available: cells.filter(c => c.cls.includes('datepicker-available-day')),
        current: cells.filter(c => c.cur).map(c => c.day + ' ' + (c.cls.includes('datepicker-available-day') ? 'available' : 'unavailable')),
        next_disabled: !!document.querySelector('a.ui-datepicker-next.ui-state-disabled'),
      };
    })()""")


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
    txt = (js("document.body.innerText") or "").replace("\u00a0", " ")
    lines = [re.sub(r"\s+", " ", line).strip() for line in txt.splitlines() if line.strip()]
    try:
        index = next(n for n, line in enumerate(lines) if line.startswith("Date Selected"))
    except StopIteration:
        return {"date_selected": None, "days": []}
    selected = lines[index]
    days = []
    for line in lines[index + 1:]:
        if line.startswith("Availability") or re.match(r"\d+ spaces", line):
            break
        line = line.split("Availability")[0].strip()
        if not line:
            break
        if line.startswith("Day #"):
            days.append(line)
        elif not days:
            days.append(line)
            break
        else:
            break
    return {"date_selected": selected, "days": days}


ab("open", url)
# Chrome renders the widget asynchronously; poll until the calendar exists.
for _ in range(12):
    if month_state():
        break
    ab("wait", "1000")
captured = datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")
result = {"id": ident, "url": url, "captured_at": captured, "months": [], "series": []}
seen = set()
for _ in range(months):
    state = month_state()
    if not state:
        break
    entry = {"title": state["title"],
             "cells_parsed": state.get("cells_parsed", 0),
             "headers": state.get("headers") or [],
             "available": [cell["day"] for cell in state["available"]],
             "clicks": []}
    for cell in state["available"]:
        if not click_day(cell["day"]):
            continue
        # Wait for the AJAX detail to settle, polling for the slot line.
        detail = {"date_selected": None, "days": []}
        for _ in range(8):
            ab("wait", "400")
            detail = details()
            if detail.get("days"):
                break
        entry["clicks"].append(detail)
        key = json.dumps(detail, sort_keys=True)
        if key not in seen:
            seen.add(key)
            result["series"].append(detail)
    result["months"].append(entry)
    if state.get("next_disabled"):
        break
    js("(() => { const a=document.querySelector('a.ui-datepicker-next'); if(a) a.click(); return true; })()")
    ab("wait", "800")

result["coverage"] = coverage.calendar(months, result["months"])

raw = js("document.body.innerText") or ""
(out / (ident + ".rgp.txt")).write_text(raw)
(out / (ident + ".rgp.json")).write_text(json.dumps(result, indent=1) + "\n")
print("%s: %d/%d months, %d highlighted dates, %d distinct series" % (
    ident, result["coverage"]["months_read"], months,
    sum(len(month["available"]) for month in result["months"]),
    len(result["series"])))
