#!/usr/bin/env python3
"""Capture a Redpoint HQ (rphq.com) programme calendar as structured JSON.

Usage: tools/rphq.py <session> <out-dir> <id> <url> [months]

Reads the PrimeVue datepicker's day cells (their aria-label carries the state:
"November 24, 2026, Available" / ", Waitlist" / "Full/Closed" / no suffix), clicks every
available date, stores the course detail each click reveals, then advances a month.
Read-only: it never books.

Coverage is recorded per month — requested, read, and the number of day cells parsed —
so an empty calendar can be told from a page that never rendered. When the portal refuses
for a reason of its own ("This plan is inactive") the rendered text carries it, and the
capture keeps that text for the reviewer.
"""
import datetime
import json
import pathlib
import subprocess
import sys

import coverage

session, out_dir, ident, url = sys.argv[1:5]
months = int(sys.argv[5]) if len(sys.argv) > 5 else 4
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)


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
    title: titleEl ? titleEl.innerText.replace(/\s+/g, ' ').trim() : null,
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


def wait_cells():
    for _ in range(15):
        state = js(CELLS_JS)
        if isinstance(state, dict) and len(state.get("cells") or []) > 10:
            return state
        ab("wait", "1500")
    return {"cells": [], "headers": []}


def state_of(label):
    low = label.lower()
    for word in ("available", "waitlist", "full/closed"):
        if low.endswith(", " + word):
            return word
    return "unmarked"


ab("open", url)
state = wait_cells()
result = {"id": ident, "url": url,
          "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
          "months": [], "available": [], "details": {}}

for _ in range(months):
    if not state.get("cells"):
        result["months"].append({"error": "no calendar cells"})
        break
    month = {"title": state.get("title"),
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
    if not js(NEXT_JS):
        break
    ab("wait", "1500")
    state = wait_cells()

result["coverage"] = coverage.calendar(months, result["months"])

raw = js("document.body.innerText") or ""
(out / (ident + ".rphq.txt")).write_text(raw)
(out / (ident + ".rphq.json")).write_text(json.dumps(result, indent=1) + "\n")
print("%s: %d/%d months, %d available dates: %s" % (
    ident, result["coverage"]["months_read"], months,
    len(result["available"]), result["available"][:8]))
