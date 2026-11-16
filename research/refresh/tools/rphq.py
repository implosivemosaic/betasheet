#!/usr/bin/env python3
"""Capture a Redpoint HQ (rphq.com) programme calendar as structured JSON.

Usage: tools/rphq.py <session> <out-dir> <id> <url> [months]

Reads the PrimeVue datepicker's day cells (their aria-label carries the state:
"November 24, 2026, Available" / ", Waitlist" / "Full/Closed" / no suffix), clicks every
available date, stores the course detail each click reveals, then advances a month.
Read-only: it never books.

Two facts make the difference between a capture and a guess:

* **Which month the grid is showing** is read from the cells themselves. The datepicker's
  header element differs between PrimeVue builds and is often absent, but each day cell
  states its own date, so the month is the majority of its cells.
* **Clicking a day can move the grid.** A date belonging to the following month is drawn
  as spillover in this month's grid; clicking it switches the datepicker to that month.
  The next "Next Month" then advances from *there*, which silently skips a month. So the
  panel is restored after clicking, and the capture waits for the month it expects rather
  than for whatever renders.

Coverage is recorded per month — requested, read, and the day cells parsed — and the
sequence is checked, so a skipped or duplicated month is a stated problem rather than a
plausible-looking 3/3.
"""
import collections
import datetime
import json
import pathlib
import re
import subprocess
import sys

import coverage

session, out_dir, ident, url = sys.argv[1:5]
months = int(sys.argv[5]) if len(sys.argv) > 5 else 4
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)

LOAD_TIMEOUT = "waiting for load state"
MONTHS = ("January February March April May June July August September October "
          "November December").split()
CELL_LABEL = re.compile(r"^([A-Z][a-z]+)\s+(\d{1,2}),\s*(\d{4})")


def ab(*args, timeout=120):
    result = subprocess.run(["agent-browser", "--session", session, *args],
                            capture_output=True, text=True, timeout=timeout)
    if result.returncode != 0:
        raise RuntimeError("agent-browser %s failed: %s" % (args[0], result.stderr.strip()[:200]))
    return result.stdout.strip()


def js(expr):
    raw = ab("eval", expr)
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        return raw
    # eval returns the JS value as JSON; a JSON.stringify() inside the page therefore
    # arrives string-wrapped. Unwrap until it stops being a string.
    for _ in range(2):
        if not isinstance(value, str):
            break
        try:
            value = json.loads(value)
        except json.JSONDecodeError:
            break
    return value


CELLS_JS = """(() => {
  const tds = [...document.querySelectorAll('td[aria-label]')];
  const headers = [...document.querySelectorAll('th')].map(th => th.textContent.trim())
    .filter(Boolean).slice(0, 7);
  const titleEl = document.querySelector('.p-datepicker-title, [class*=datepicker-title]');
  return JSON.stringify({
    title: titleEl ? titleEl.innerText.replace(/\\s+/g, ' ').trim() : null,
    headers: headers,
    cells: tds.map(td => {
      const sp = td.querySelector('span[role=button]') || td;
      return {
        label: (sp.getAttribute('aria-label') || '').trim(),
        disabled: sp.getAttribute('data-p-disabled') === 'true',
        today: td.getAttribute('data-p-today') === 'true',
        other: td.getAttribute('data-p-other-month') === 'true',
      };
    }),
  });
})()"""

CLICK_JS = """(label) => {
  const tds = [...document.querySelectorAll('td[aria-label]')];
  const td = tds.find(t => {
    const sp = t.querySelector('span[role=button]') || t;
    return (sp.getAttribute('aria-label') || '').trim() === label;
  });
  if (!td) return 'no-cell';
  const sp = td.querySelector('span[role=button]') || td;
  sp.click();
  return 'clicked';
}"""

NEXT_JS = """(() => {
  const b = [...document.querySelectorAll('button')].find(
    b => (b.getAttribute('aria-label') || '') === 'Next Month');
  if (!b) return false;
  b.click();
  return true;
})()"""

PREV_JS = """(() => {
  const b = [...document.querySelectorAll('button')].find(
    b => (b.getAttribute('aria-label') || '') === 'Previous Month');
  if (!b) return false;
  b.click();
  return true;
})()"""


def wait_cells():
    for _ in range(15):
        state = js(CELLS_JS)
        if isinstance(state, dict) and len(state.get("cells") or []) > 10:
            return state
        ab("wait", "1500")
    return {"cells": [], "headers": []}


def wait_for_change(previous, tries=10):
    """Wait until the grid is showing a month other than `previous`."""
    state = {"cells": [], "headers": []}
    for _ in range(tries):
        state = wait_cells()
        title, _ = title_of(state)
        if title and title != previous:
            return state
        ab("wait", "1000")
    return state


def wait_for_month(expected, tries=10):
    """Wait until the grid shows `expected`.

    If the widget lands somewhere else, return that grid: the caller records the month
    it actually read, and the coverage sequence check reports the hole. Guessing that we
    arrived would defeat the purpose of asking.
    """
    state = {"cells": [], "headers": []}
    for _ in range(tries):
        state = wait_cells()
        title, _ = title_of(state)
        if title == expected:
            return state
        ab("wait", "1000")
    return state


def restore_panel(title, tries=3):
    """Undo any month change caused by clicking a day, so `Next` means what it says."""
    for _ in range(tries):
        state = wait_cells()
        current, _ = title_of(state)
        if current is None or current == title:
            return state, None
        target = coverage.month_key(title)
        here = coverage.month_key(current)
        if target and here and target < here:
            js(PREV_JS)
        else:
            js(NEXT_JS)
        ab("wait", "1500")
    state = wait_cells()
    current, _ = title_of(state)
    moved = None if current == title else "clicking a date moved the grid to %s" % current
    return state, moved


def derive_month_title(cells):
    """The month this grid is showing, read from its own cells.

    The datepicker's header element differs between PrimeVue builds and is often absent
    from the DOM entirely, but every day cell's aria-label carries its full date, so the
    month the grid is showing is a fact the cells already state: it is the month most of
    its cells belong to. `data-p-other-month` is not consulted — this build marks the
    shown month's own days as "other", so trusting the flag shifts the label a month.
    A tie leaves the title unknown.
    """
    counts = collections.Counter()
    for cell in cells:
        match = CELL_LABEL.match(cell.get("label") or "")
        if match and match.group(1) in MONTHS:
            counts[(int(match.group(3)), MONTHS.index(match.group(1)) + 1)] += 1
    if not counts:
        return None, None
    (year, month), hits = counts.most_common(1)[0]
    if len(counts) > 1 and list(counts.values()).count(hits) > 1:
        return None, None
    return "%s %d" % (MONTHS[month - 1], year), "cells"


def title_of(state):
    if not state or not state.get("cells"):
        return None, None
    return (state.get("title"), "header") if state.get("title") else \
        derive_month_title(state["cells"])


def expected_after(title):
    key = coverage.month_key(title)
    if not key:
        return None
    year, month = coverage.next_key(key)
    return "%s %d" % (MONTHS[month - 1], year)


def state_of(label):
    low = label.lower()
    for word in ("available", "waitlist", "full/closed"):
        if low.endswith(", " + word):
            return word
    return "unmarked"


note = None
try:
    ab("open", url)
except RuntimeError as exc:
    if LOAD_TIMEOUT not in str(exc):
        raise
    note = "navigation load-state timed out; polled the DOM instead"
state = wait_cells()
if not state.get("cells") and note is None:
    note = "no day cells rendered"
result = {"id": ident, "url": url,
          "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
          "months": [], "available": [], "details": {}}

for _ in range(months):
    if not state.get("cells"):
        result["months"].append({"error": "no calendar cells"})
        break
    title, title_from = title_of(state)
    month = {"title": title, "title_from": title_from,
             "cells": [{"label": cell["label"], "state": state_of(cell["label"]),
                        "disabled": cell["disabled"], "other_month": cell["other"]}
                       for cell in state["cells"]],
             "cells_parsed": len(state["cells"]),
             "headers": state.get("headers") or [],
             "available": [cell["label"] for cell in state["cells"]
                           if state_of(cell["label"]) == "available" and not cell["disabled"]]}
    result["months"].append(month)
    for label in month["available"]:
        if js("(%s)(%s)" % (CLICK_JS, json.dumps(label))) != "clicked":
            continue
        text = ""
        for _ in range(6):
            ab("wait", "1200")
            body = js("document.body.innerText") or ""
            key = label.split(",")[0].upper()
            if key in body and "Powered by Redpoint HQ" in body:
                text = body
                tail = body.split(key, 1)[-1]
                if "Redpoint HQ" in tail and len(tail) > 40:
                    break
        result["available"].append(label)
        result["details"][label] = text
    # Clicking a spillover date switches the grid to that month; put it back so the
    # advance below is one panel forward from the panel just read.
    state, moved = restore_panel(title)
    if moved:
        result.setdefault("notes", []).append(moved)
    if not js(NEXT_JS):
        break
    ab("wait", "1500")
    wanted = expected_after(title)
    state = wait_for_month(wanted) if wanted else wait_for_change(title)

result.setdefault("notes", [])
if note:
    result["notes"].append(note)
# A date drawn as spillover in one panel and again in its own panel is one date.
result["available"] = list(dict.fromkeys(result["available"]))
result["coverage"] = coverage.calendar(months, result["months"])

raw = js("document.body.innerText") or ""
(out / (ident + ".rphq.txt")).write_text(raw)
(out / (ident + ".rphq.json")).write_text(json.dumps(result, indent=1) + "\n")
print("%s: %d panels %s, %d available: %s%s" % (
    ident, result["coverage"]["months_read"], result["coverage"]["months_observed"],
    len(result["available"]), result["available"][:8],
    "" if result["coverage"]["complete"] else
    " | NOT COMPLETE: " + "; ".join(result["coverage"]["problems"])))
