"""Compare two capture records and say what changed.

`extract.py` answers "what did we read"; this answers "does it differ from the baseline".
The two are deliberately separate, because a capture that read nothing must never be able
to claim that a source is unchanged — that is the failure that let 165 of 562 sources in
the November run read `unchanged` while holding no comparable content.

    record = extract.extract(path)
    verdict = compare.compare_source(baseline_record, record)

Rules, in the order they apply:

1. Eligibility before comparison. Both captures must be `read` or `read-empty`; anything
   else is `incomplete` and the baseline stands. Two verified empty calendars are
   therefore `unchanged`, while two failures can never be mistaken for each other.
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


def _fingerprint(items, basis):
    payload = json.dumps(items, sort_keys=True, ensure_ascii=False)
    return hashlib.sha256(payload.encode()).hexdigest(), basis


def _verdict(current, status, **fields):
    verdict = {
        "source_id": current.get("source_id"), "type": current.get("type"),
        "status": status,
        "outcome": {"current": current.get("outcome")},
        "coverage": {"met": current.get("outcome") in ex.BASELINE_OUTCOMES,
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


def compare_source(baseline, current):
    """The one function the registry calls. Never writes; returns a verdict."""
    if baseline is None:
        return _verdict(current, NEW, fingerprint_basis=None)

    if baseline.get("outcome") not in ex.BASELINE_OUTCOMES:
        return _incomplete(baseline, current, "baseline-not-verified",
                           ["previous capture was %s" % baseline.get("outcome")])
    if current.get("outcome") not in ex.BASELINE_OUTCOMES:
        return _incomplete(baseline, current, "capture-not-verified",
                           current.get("notes") or [])

    kind = current.get("type")
    if kind in ("rockgympro", "redpoint"):
        return _compare_calendar(baseline, current)
    if kind == "page":
        return _compare_page(baseline, current)
    return _compare_social(baseline, current)


# ----------------------------------------------------------------------------- calendars

def _compare_calendar(baseline, current):
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

    added, removed, suppressed = [], [], []
    for key in curr_map.keys() - base_map.keys():
        added.append(curr_map[key])
    for key in base_map.keys() - curr_map.keys():
        entry = base_map[key]
        if _month_of(entry["date"]) not in window:
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
            if _identity(before[0]) != _identity(after[0]):
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

    # Availability is separate from schedule: same slot, different booking state.
    availability = []
    for key in curr_map.keys() & base_map.keys():
        before, after = base_map[key], curr_map[key]
        if before.get("state") != after.get("state"):
            availability.append({"date": after["date"], "start": after.get("start"),
                                 "end": after.get("end"),
                                 "from": before.get("state"), "to": after.get("state")})

    fingerprint, basis = _fingerprint(
        sorted([list(_identity(e)) for e in curr_future]), "future-sessions")

    changed = bool(added or removed or moved)
    verdict = _verdict(current, CHANGED if changed else UNCHANGED)
    verdict["outcome"]["baseline"] = baseline.get("outcome")
    verdict["fingerprint"], verdict["fingerprint_basis"] = fingerprint, basis
    verdict["changes"].update({"added": _public(added), "removed": _public(removed),
                               "moved": moved})
    verdict["availability_changes"] = availability
    verdict["suppressed"] = [{"what": s["what"], "reason": s["reason"]} for s in suppressed]
    verdict["coverage"]["detail"] = {"window": sorted(window),
                                     "baseline_window": sorted(_window_months(baseline))}
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

def _compare_social(baseline, current):
    before = {p["id"]: p for p in baseline.get("posts") or [] if p.get("id")}
    after = {p["id"]: p for p in current.get("posts") or [] if p.get("id")}
    unidentified = len([p for p in current.get("posts") or [] if not p.get("id")])

    if not before and not after:
        return _incomplete(baseline, current, "no-identifiable-posts",
                           ["neither capture read a post with a stable id"])

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
