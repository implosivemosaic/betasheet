"""The coverage block every capture writes.

A capture that cannot describe its own coverage cannot be a baseline, so the tools state
what they looked at rather than leaving it to inference: which months were requested and
which were actually read, and per month the populated grid — cell count and header row —
not merely that a table element existed.

Counting panels is not coverage. A datepicker that opens on November and then shows
January and February has read three panels and inspected two of the three months asked
for; December is a hole, and reporting `3/3` hides it. So the sequence is checked, not
just the total: each requested month exactly once, in order.

Imported by rgp.py, rphq.py and page.py. Pure functions; no I/O.
"""

import pathlib
import sys

# One implementation of "which months is this, and is the sequence right". The judging
# module owns it; a capture tool that computed it differently could disagree with the
# comparison that reads its output.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))
from extract import _MONTH_NAMES as MONTHS  # noqa: E402
from extract import month_key, next_month, sequence_problems  # noqa: E402


next_key = next_month


def calendar(months_requested, months, days=None):
    """`months` is [{"title", "cells_parsed", "headers"}] as the tool saw them.

    `days` is the per-date accounting the Rock Gym Pro tool keeps: how many dates the
    grid highlighted, how many were read, and how many returned no session.
    """
    titles = [month.get("title") for month in months]
    problems = sequence_problems(titles, months_requested)
    window = [title for title in titles if title]
    block = {
        "contract": "calendar-3-months",
        "months_requested": months_requested,
        "months_read": len(window),
        "months_observed": window,
        "window": {"first": window[0] if window else None,
                   "last": window[-1] if window else None},
        "inspected": {"months": [{"title": month.get("title"),
                                  "cells_parsed": month.get("cells_parsed", 0),
                                  "headers": month.get("headers") or []}
                                 for month in months]},
        "challenge_detected": None,
        "complete": not problems,
        "problems": problems,
        "errors": [],
    }
    if days is not None:
        block["days"] = days
        unread = days.get("unread", 0)
        if unread:
            block["complete"] = False
            block["problems"] = problems + [
                "%d highlighted date(s) returned no session detail" % unread]
    return block


def page(lines, challenge=None, notice=None):
    return {
        "contract": "web-page",
        "months_requested": 1,
        "months_read": 1 if not challenge else 0,
        "months_observed": [],
        "window": {"first": None, "last": None},
        "inspected": {"lines": lines},
        "challenge_detected": challenge,
        "notice": notice,
        "complete": not challenge,
        "problems": [] if not challenge else ["page is a %s shell" % challenge],
        "errors": [],
    }


def social(posts_read, anchor_id, anchor_reached, stopping_post, stopped_reason,
           minimum=4):
    complete = bool(anchor_reached) or posts_read >= minimum
    return {
        "contract": "social-window",
        "months_requested": None,
        "months_read": None,
        "months_observed": [],
        "window": {"first": None, "last": None},
        "inspected": {"posts_read": posts_read, "minimum": minimum},
        "anchor_id": anchor_id,
        "anchor_reached": anchor_reached,
        "stopping_post": stopping_post,
        "stopped_reason": stopped_reason,
        "challenge_detected": None,
        "complete": complete,
        "problems": [] if complete else [
            "read %d of %d posts and did not reach the baseline anchor"
            % (posts_read, minimum)],
        "errors": [],
    }
