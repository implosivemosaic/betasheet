"""Compare two capture records and say what changed.

`extract.py` answers "what did we read"; this answers "does it differ from the baseline".
The two are deliberately separate, because a capture that read nothing must never be able
to claim that a source is unchanged — that is the failure that let 165 of 562 sources in
the November run read `unchanged` while holding no comparable content.

    record = extract.extract(path)
    verdict = compare.compare_source(baseline_record, record)

Rules, in the order they apply:

1. Eligibility before comparison. Both captures must be `read` or `read-empty` **and**
   declare complete coverage; anything else is `incomplete` and the baseline stands. The
   outcome alone is not enough: a capture can read one post of a feed and still call
   itself `read`, so the declared coverage is the half that decides whether the
   comparison is allowed to say anything. Two verified empty calendars are therefore
   `unchanged`, while two failures can never be mistaken for each other.
2. A fingerprint describes what is still bookable. Elapsed entries and the read window
   are coverage, not content, so a calendar whose only difference is a week passing
   hashes equal.
3. Removal is claimed narrowly: only inside the months the current capture read, and
   only for entries the current capture's date could still sell. Everything else is
   suppressed with a reason.
4. A move needs an unambiguous pairing; several legitimate slots on one date stay
   `added`/`removed` and are flagged for review.
5. Availability is its own channel. A date going available → full is neither a schedule
   change nor a cancellation.
6. Notices are findings, not content. "This plan is inactive" is returned as a notice for
   a reviewer; it never advances a baseline and never means cancelled.
"""
from __future__ import annotations

import hashlib
import json
from datetime import date

try:
    from . import extract as ex
except ImportError:  # run as a script or from its own directory
    import extract as ex

UNCHANGED, CHANGED, NEW, INCOMPLETE = "unchanged", "changed", "new-baseline", "incomplete"


def _date(value):
    return ex._iso(value)


def _identity(entry):
    return (entry.get("date"), entry.get("start"), entry.get("end"), entry.get("cohort"))


def _month_of(value):
    return value[:7] if value else None


def _window_months(record):
    return set(record.get("window", {}).get("months") or [])


def _order_value(value):
    """Total order for one stored field, with unknown (`None`) first.

    A session whose time was never announced carries `start=None`. Comparing that with
    `"18:30"` raises, and it raises while building the fingerprint — after the comparison
    has already decided there is a change, so a complete read crashed and a partial one
    lost its observations. Comparing the values themselves is not the point: the
    fingerprint only has to be stable, so unknown sorts first and equal content hashes
    equal. The values in the payload stay exactly as captured.
    """
    return (value is not None, "" if value is None else str(value))


def _identity_order(entry):
    return tuple(_order_value(value) for value in _identity(entry))


def _fingerprint(items, basis):
    payload = json.dumps(items, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode()).hexdigest(), basis


def _eligible(record):
    """Can this capture stand as a baseline, or be compared against one?

    Two independent halves, both required: the outcome says the source was read, the
    declared coverage says the read was the whole of what the contract asks for. A
    capture that read one post of a fifteen-post window is `read` and incomplete, and
    comparing it would advance the baseline to a shrinking window.
    """
    if not record:
        return False
    if record.get("outcome") not in ex.BASELINE_OUTCOMES:
        return False
    return bool((record.get("coverage") or {}).get("complete"))


def _verdict(current, status, **fields):
    verdict = {
        "source_id": current.get("source_id"), "type": current.get("type"),
        "status": status,
        "outcome": {"current": current.get("outcome")},
        "coverage": {"met": _eligible(current),
                     "detail": current.get("window")},
        "fingerprint": None, "fingerprint_basis": None,
        "changes": {"added": [], "removed": [], "moved": [], "edited": [],
                    "added_posts": [], "edited_posts": [], "not_seen": []},
        "availability_changes": [], "suppressed": [], "notices": [], "notes": [],
    }
    verdict["notices"] = [current["notice"]] if current.get("notice") else []
    verdict.update(fields)
    return verdict


def _incomplete(baseline, current, reason, notes=()):
    verdict = _verdict(current, INCOMPLETE, notes=list(notes))
    verdict["outcome"]["baseline"] = baseline.get("outcome") if baseline else None
    verdict["coverage"]["met"] = False
    verdict["coverage"]["reason"] = reason
    return verdict


def _provisional(baseline, current, reason, notes=()):
    """An ineligible capture still says what it saw.

    Two different questions hide behind "incomplete". *May this capture move the
    baseline?* No. *Did it show anything the catalogue might need?* Often yes: dates in
    the months it did read, posts above a feed it stopped short of. Throwing those away
    loses a real observation, so they are returned as `provisional` and the registry
    saves them as findings that a later eligible capture must confirm.

    Only positive observations travel. A removal needs the whole window, and a move needs
    an unambiguous pairing, so neither is ever claimed from a partial read.
    """
    verdict = _incomplete(baseline, current, reason, notes)
    if not baseline:
        return verdict
    try:
        kind = current.get("type")
        if kind in ("rockgympro", "redpoint"):
            seen = _compare_calendar(baseline, current)
        elif kind == "page":
            seen = _compare_page(baseline, current)
        else:
            seen = _compare_social(baseline, current)
    except Exception as exc:  # a provisional reading must never mask the real verdict
        verdict["notes"].append("provisional reading failed: %s" % exc)
        return verdict
    for field in ("added", "added_posts", "edited_posts"):
        verdict["changes"][field] = seen["changes"].get(field) or []
    verdict["provisional"] = any(verdict["changes"][field]
                                 for field in ("added", "added_posts", "edited_posts"))
    if verdict["provisional"]:
        verdict["notes"].append(
            "provisional: observed additions from an incomplete capture; "
            "nothing is removed and no baseline moves")
    return verdict


def compare_source(baseline, current):
    """The one function the registry calls. Never writes; returns a verdict."""
    if baseline is None:
        # No baseline yet. A capture that cannot be a baseline does not create one, so a
        # failed first attempt leaves the source unbaselined rather than "new".
        if not _eligible(current):
            return _incomplete(baseline, current, "capture-not-verified",
                               ["first capture is not baseline-eligible"] +
                               list(current.get("notes") or []))
        return _verdict(current, NEW, fingerprint_basis=None)

    if not _eligible(baseline):
        return _incomplete(baseline, current, "baseline-not-verified",
                           ["previous capture was %s with coverage %s" % (
                               baseline.get("outcome"),
                               "complete" if (baseline.get("coverage") or {}).get("complete")
                               else "incomplete")])
    if current.get("outcome") not in ex.BASELINE_OUTCOMES:
        return _provisional(baseline, current, "capture-not-verified",
                            current.get("notes") or [])
    if not _eligible(current):
        return _provisional(baseline, current, "coverage-incomplete",
                            list(current.get("notes") or []) +
                            ["declared coverage was not met, so nothing may be concluded"])

    kind = current.get("type")
    if kind in ("rockgympro", "redpoint"):
        return _compare_calendar(baseline, current)
    if kind == "page":
        return _compare_page(baseline, current)
    return _compare_social(baseline, current)


# ----------------------------------------------------------------------------- calendars

def _compare_page_channel(baseline, current, reason):
    """Compare the offering's page text when its calendar was not observed.

    Two channels answer two questions. The page channel says whether the description
    changed; the calendar channel says whether sessions did. A readable description with
    no rendered calendar answers the first and nothing about the second, so it can report
    a page change but must never claim a session change, a removal or a cancellation —
    and it must not let a calendar baseline advance.
    """
    before = (baseline.get("page") or {}).get("text_sha")
    after = (current.get("page") or {}).get("text_sha")
    delta = [] if before == after else [{"field": "page_text_sha",
                                        "from": before, "to": after}]
    verdict = _verdict(current, CHANGED if delta else UNCHANGED)
    verdict["outcome"]["baseline"] = baseline.get("outcome")
    verdict["fingerprint"], verdict["fingerprint_basis"] = after, "page-text"
    verdict["changes"]["edited"] = delta
    verdict["coverage"]["met"] = False
    verdict["coverage"]["page_met"] = bool(after)
    verdict["coverage"]["calendar_observed"] = False
    verdict["coverage"]["reason"] = reason
    verdict["notes"] = list(current.get("notes") or []) + [
        "calendar not observed; compared page text only",
        "page content changed; interpretation pending" if delta
        else "page text identical; no session claim made",
    ]
    return verdict


def _compare_calendar(baseline, current):
    if not current.get("calendar_observed", True):
        return _compare_page_channel(baseline, current, "calendar-not-observed")
    if not baseline.get("calendar_observed", True):
        return _compare_page_channel(baseline, current, "baseline-calendar-not-observed")

    ref = _date(current.get("captured_at"))
    if ref is None:
        return _incomplete(baseline, current, "no-capture-date")

    window = _window_months(current)
    base_all = [e for e in baseline.get("entries") or [] if e.get("date")]
    curr_all = [e for e in current.get("entries") or [] if e.get("date")]

    base_future = [e for e in base_all if e["date"] >= ref]
    curr_future = [e for e in curr_all if e["date"] >= ref]

    base_map = {_identity(e): e for e in base_future}
    curr_map = {_identity(e): e for e in curr_future}

    # A date the capture clicked but could not read is a hole in the evidence, not an
    # absence of sessions. Without this, a footer where the session list should be reads
    # as "the session was cancelled".
    unread = {(u.get("month"), u.get("day")) for u in current.get("unread") or []
              if u.get("day") is not None}

    added, removed, suppressed = [], [], []
    for key in curr_map.keys() - base_map.keys():
        added.append(curr_map[key])
    for key in base_map.keys() - curr_map.keys():
        entry = base_map[key]
        month_day = (int(entry["date"][5:7]), int(entry["date"][8:10]))
        if month_day in unread:
            suppressed.append({"what": entry["date"], "reason": "unread-this-capture",
                               "entry": entry})
        elif _month_of(entry["date"]) not in window:
            suppressed.append({"what": entry["date"], "reason": "outside-window",
                               "entry": entry})
        else:
            removed.append(entry)
    for entry in base_all:
        if entry["date"] < ref:
            suppressed.append({"what": entry["date"], "reason": "elapsed", "entry": entry})

    # A time change is a move, but only when the pairing cannot be a different slot.
    moved, ambiguous = [], []
    by_slot = {}
    for entry in base_future:
        by_slot.setdefault((entry["date"], entry.get("cohort")), ([], []))[0].append(entry)
    for entry in curr_future:
        by_slot.setdefault((entry["date"], entry.get("cohort")), ([], []))[1].append(entry)

    for slot, (before, after) in by_slot.items():
        if len(before) == 1 and len(after) == 1:
            if _identity(before[0]) == _identity(after[0]):
                continue
            if before[0].get("start") is None or after[0].get("start") is None:
                # An unknown time is not evidence of a time change. Claiming a move here
                # would both invent a fact and drop the two observations out of
                # added/removed, so they stay, flagged, for a reviewer.
                ambiguous.extend([before[0], after[0]])
                continue
            moved.append({"date": slot[0], "cohort": slot[1],
                          "from": {"start": before[0].get("start"),
                                   "end": before[0].get("end")},
                          "to": {"start": after[0].get("start"),
                                 "end": after[0].get("end")},
                          "line": after[0].get("line")})
            for entry in (before[0], after[0]):
                for bucket in (added, removed):
                    if entry in bucket:
                        bucket.remove(entry)
        elif before and after:
            for entry in after:
                if entry in added:
                    ambiguous.append(entry)
            for entry in before:
                if entry in removed:
                    ambiguous.append(entry)

    for entry in ambiguous:
        entry["ambiguous_pairing"] = True

    # One stable order for everything a receipt carries. The keys come from set
    # differences, whose iteration order is not guaranteed across processes, and a
    # fingerprint that reorders between runs would look like a content change.
    added.sort(key=_identity_order)
    removed.sort(key=_identity_order)

    # Availability is separate from schedule: same slot, different booking state.
    availability = []
    for key in sorted(curr_map.keys() & base_map.keys(),
                      key=lambda k: tuple(_order_value(part) for part in k)):
        before, after = base_map[key], curr_map[key]
        if before.get("state") != after.get("state"):
            availability.append({"date": after["date"], "start": after.get("start"),
                                 "end": after.get("end"),
                                 "from": before.get("state"), "to": after.get("state")})

    fingerprint, basis = _fingerprint(
        [list(_identity(e)) for e in sorted(curr_future, key=_identity_order)],
        "future-sessions")

    changed = bool(added or removed or moved)
    verdict = _verdict(current, CHANGED if changed else UNCHANGED)
    verdict["outcome"]["baseline"] = baseline.get("outcome")
    verdict["fingerprint"], verdict["fingerprint_basis"] = fingerprint, basis
    moved.sort(key=lambda m: (_order_value(m["date"]), _order_value(m["cohort"]),
                              _order_value(m["from"].get("start"))))
    verdict["changes"].update({"added": _public(added), "removed": _public(removed),
                               "moved": moved})
    verdict["availability_changes"] = availability
    verdict["suppressed"] = [{"what": s["what"], "reason": s["reason"]} for s in suppressed]
    verdict["coverage"]["detail"] = {"window": sorted(window),
                                     "baseline_window": sorted(_window_months(baseline))}
    verdict["coverage"]["calendar_observed"] = True
    verdict["notes"] = list(current.get("notes") or [])
    if not curr_future and not added:
        verdict["notes"].append("no bookable entry after %s" % ref)
    return verdict


def _public(entries):
    return [{"date": e.get("date"), "start": e.get("start"), "end": e.get("end"),
             "state": e.get("state"), "cohort": e.get("cohort"),
             "line": e.get("line"), "ambiguous_pairing": e.get("ambiguous_pairing", False)}
            for e in entries]


# ---------------------------------------------------------------------------------- page

def _compare_page(baseline, current):
    before = (baseline.get("entries") or [{}])[0].get("text_sha")
    after = (current.get("entries") or [{}])[0].get("text_sha")
    if not before or not after:
        return _incomplete(baseline, current, "page-text-missing")

    delta = [] if before == after else [{"field": "text_sha",
                                         "from": before, "to": after}]
    verdict = _verdict(current, CHANGED if delta else UNCHANGED)
    verdict["outcome"]["baseline"] = baseline.get("outcome")
    verdict["fingerprint"], verdict["fingerprint_basis"] = after, "page-text"
    verdict["changes"]["edited"] = delta
    return verdict


# -------------------------------------------------------------------------------- social

def _compare_social(baseline, current, anchor=None):
    before = {p["id"]: p for p in baseline.get("posts") or [] if p.get("id")}
    after = {p["id"]: p for p in current.get("posts") or [] if p.get("id")}
    unidentified = len([p for p in current.get("posts") or [] if not p.get("id")])

    if not before and not after:
        return _incomplete(baseline, current, "no-identifiable-posts",
                           ["neither capture read a post with a stable id"])

    # A feed walk is not an enumeration. Unless this capture reached a post the baseline
    # already knew, it cannot know what it missed above that point, so it proves nothing
    # about additions and must not move the baseline.
    declared = current.get("coverage_social") or {}
    anchor = anchor or declared.get("anchor_id")
    if anchor is None:
        newest = (baseline.get("posts") or [None])[0]
        anchor = (newest or {}).get("id")
    if anchor and anchor not in after and not declared.get("anchor_reached"):
        return _provisional(baseline, current, "anchor-not-reached",
                            ["capture did not reach baseline post %s" % anchor])

    added = [after[i] for i in after.keys() - before.keys()]
    not_seen = [before[i] for i in before.keys() - after.keys()]
    edited = [after[i] for i in after.keys() & before.keys()
              if before[i].get("text_sha") and after[i].get("text_sha")
              and before[i]["text_sha"] != after[i]["text_sha"]]

    fingerprint, basis = _fingerprint(sorted(after.keys()), "post-ids")
    verdict = _verdict(current, CHANGED if (added or edited) else UNCHANGED)
    verdict["outcome"]["baseline"] = baseline.get("outcome")
    verdict["fingerprint"], verdict["fingerprint_basis"] = fingerprint, basis
    verdict["changes"]["added_posts"] = _public_posts(added)
    verdict["changes"]["edited_posts"] = _public_posts(edited)
    verdict["changes"]["not_seen"] = _public_posts(not_seen)
    if unidentified:
        verdict["notes"].append("%d post(s) carry no stable id and were not compared"
                                % unidentified)
    if not_seen and not added:
        verdict["notes"].append("%d baseline post(s) not in this capture; not deleted"
                                % len(not_seen))
    return verdict


def _public_posts(posts):
    return [{"id": p.get("id"), "kind": p.get("kind"), "published": p.get("published")}
            for p in posts]
