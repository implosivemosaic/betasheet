"""The coverage block every capture writes.

A capture that cannot describe its own coverage cannot be a baseline, so the tools state
what they looked at rather than leaving it to inference: how many months were requested
and read, and per month the populated grid — cell count and header row — not merely that
a table element existed.

Imported by rgp.py, rphq.py and page.py. Pure functions; no I/O.
"""


def calendar(months_requested, months):
    """`months` is [{"title", "cells_parsed", "headers"}] as the tool saw them."""
    window = [month["title"] for month in months if month.get("title")]
    return {
        "contract": "calendar-3-months",
        "months_requested": months_requested,
        "months_read": len(window),
        "window": {"first": window[0] if window else None,
                   "last": window[-1] if window else None},
        "inspected": {"months": [{"title": month.get("title"),
                                  "cells_parsed": month.get("cells_parsed", 0),
                                  "headers": month.get("headers") or []}
                                 for month in months]},
        "challenge_detected": None,
        "complete": len(window) == months_requested,
        "errors": [],
    }


def page(lines, challenge=None, notice=None):
    return {
        "contract": "web-page",
        "months_requested": 1,
        "months_read": 1 if not challenge else 0,
        "window": {"first": None, "last": None},
        "inspected": {"lines": lines},
        "challenge_detected": challenge,
        "notice": notice,
        "complete": not challenge,
        "errors": [],
    }


def social(posts_read, anchor_id, anchor_reached, stopping_post, stopped_reason,
           minimum=4):
    return {
        "contract": "social-window",
        "months_requested": None,
        "months_read": None,
        "window": {"first": None, "last": None},
        "inspected": {"posts_read": posts_read, "minimum": minimum},
        "anchor_id": anchor_id,
        "anchor_reached": anchor_reached,
        "stopping_post": stopping_post,
        "stopped_reason": stopped_reason,
        "challenge_detected": None,
        "complete": bool(anchor_reached) or posts_read >= minimum,
        "errors": [],
    }
