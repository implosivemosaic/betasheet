"""The refresh registry: each source's baselines in `sources.json`, the rule that moves them,
and the findings that keep unresolved changes. See REGISTRY.md.

`extract.py` says what a capture read and `compare.py` what changed. This module saves every
change as a pending finding in each cited gym's `decisions.json`, then moves the baseline the
capture was compared with. It is the only code that writes `sources.json`.
"""
import contextlib
import datetime
import fcntl
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import urllib.parse

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import compare  # noqa: E402
import extract as ex  # noqa: E402

TOOLS = HERE / "tools"
CONTRACT = {"page": "web-page", "rockgympro": "calendar-3-months",
            "redpoint": "calendar-3-months", "instagram": "social-window",
            "facebook": "social-window"}
SOCIAL = ("instagram", "facebook")
CALENDAR = ("rockgympro", "redpoint")
MONTHS_REQUESTED = 3
SOCIAL_WINDOW = 6  # Instagram posts, or Facebook scroll steps, per capture
TOOL = {"page": "page.py", "rockgympro": "rgp.py", "redpoint": "rphq.py",
        "instagram": "social_ig.py", "facebook": "social_fb.py"}
# The file each capture tool writes; `extract()` reads it. The markdown socials are November's.
PRIMARY = {"rockgympro": ("{id}.rgp.json",), "redpoint": ("{id}.rphq.json",),
           "page": ("{id}.meta.json",), "instagram": ("{id}.ig.json", "ig-{id}.md"),
           "facebook": ("{id}.fb.json", "fb-{id}.md")}
# The readable text saved beside a capture, used to describe a page change.
TEXT = ((".meta.json", ".norm.txt"), (".rgp.json", ".rgp.txt"), (".rphq.json", ".rphq.txt"))
# Fields the November registry used, now held by the baselines and `last_attempt`.
FOLDED = ("last_copy", "fingerprint", "last_checked", "coverage_note", "last_attempt")
# Query parameters that decorate a URL without selecting different content.
DECORATION = re.compile(r"^(date|month|utm_[a-z]+|fbclid|gclid|igsh|igshid|__cft__.*|__tn__)$",
                        re.I)

# Findings live beside the collectors' own records in each gym's decisions.json.
FINDER = "refresh registry"
PENDING, PROPOSED, RESOLVED = "pending", "proposed", "resolved"
UNRESOLVED = (PENDING, PROPOSED)
# A `proposed` finding stays unresolved until a production receipt shows its proposal published.
DISPOSITIONS = {"proposed": PROPOSED, "no-change": RESOLVED, "held": PENDING}
# A proposal's stable identifier, as publication receipts record it: <gym-folder>/<ref>.
PROPOSAL_REF = re.compile(r"^([a-z0-9][a-z0-9-]*)/([^/\s]+)$")


class RegistryError(Exception):
    pass


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


# ------------------------------------------------------------------------------ identity

def normalise_url(url):
    """Drop decoration only: scheme and host case, `www.`, default ports, the fragment,
    non-content query parameters, percent-encoding, repeated and trailing slashes.
    Two different paths stay two different sources."""
    parts = urllib.parse.urlsplit((url or "").strip())
    host = (parts.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]
    if parts.port and parts.port not in (80, 443):
        host = "%s:%d" % (host, parts.port)
    path = re.sub(r"/{2,}", "/", urllib.parse.unquote(parts.path)).rstrip("/").lower()
    query = sorted((k, v) for k, v in urllib.parse.parse_qsl(parts.query, keep_blank_values=True)
                   if not DECORATION.match(k))
    return host + path + ("?" + urllib.parse.urlencode(query) if query else "")


def capture_kind(path):
    """The system a capture file belongs to, from its name."""
    name = pathlib.Path(path).name
    if name.endswith(".rgp.json"):
        return "rockgympro"
    if name.endswith(".rphq.json"):
        return "redpoint"
    if name.endswith(".meta.json"):
        return "page"
    if name.endswith(".ig.json") or (name.startswith("ig-") and name.endswith(".md")):
        return "instagram"
    if name.endswith(".fb.json") or (name.startswith("fb-") and name.endswith(".md")):
        return "facebook"
    return None


def system_for(source, capture_kinds=()):
    """Which extractor reads a source. A Rock Gym Pro offering (`bo=`, `offering_guid=`) is a
    calendar and a widget index (`bw=`) is a discovery page. A programme path is a Redpoint
    calendar on rphq.com, or on a portal domain whose saved capture shows it is one."""
    kind = source.get("type")
    if kind in SOCIAL:
        return kind
    parts = urllib.parse.urlsplit(source.get("url") or "")
    host = (parts.hostname or "").lower()
    if host.endswith("rockgympro.com"):
        offering = re.search(r"(^|&)(bo|offering_guid)=", parts.query)
        return "rockgympro" if offering else "page"
    if "/programs/" in parts.path and (host.endswith("rphq.com") or "redpoint" in capture_kinds):
        return "redpoint"
    return "page"


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


# --------------------------------------------------------------------------- eligibility

def unproven_empty(record):
    """A calendar whose clicked days all answered "no available times", read by a tool that
    declared no coverage. An unavailable response proves neither an empty calendar nor a
    complete read, so only declared, complete coverage lets such a capture be a baseline."""
    return (record.get("evidence") == "clicked-no-times"
            and bool((record.get("coverage") or {}).get("recovered")))


def legacy_slots(record):
    """A Rock Gym Pro calendar read by the November tool, which kept one session per
    highlighted date. Its dates are evidence; its time slots are not complete. The current
    tool declares its coverage, so a reconstructed coverage marks the old one."""
    return (record is not None and record.get("type") == "rockgympro"
            and record.get("calendar_observed", True)
            and bool((record.get("coverage") or {}).get("recovered"))
            and any(entry.get("date") for entry in record.get("entries") or []))


def eligible(record, system):
    """A capture may become a baseline only when it read the source and met its declared
    coverage. Social coverage must be declared by a social-window capture: a historical
    summary whose coverage was reconstructed afterwards never qualifies."""
    coverage = record.get("coverage") or {}
    if record.get("outcome") not in ex.BASELINE_OUTCOMES or coverage.get("complete") is not True:
        return False
    if system in SOCIAL and coverage.get("recovered"):
        return False
    return not unproven_empty(record)


def why_not(record, system):
    coverage = record.get("coverage") or {}
    if record.get("outcome") not in ex.BASELINE_OUTCOMES:
        reason = record.get("challenge") or record.get("notice") or "; ".join(
            record.get("notes") or [])
        return "capture %s%s" % (record.get("outcome"), " (%s)" % reason if reason else "")
    if coverage.get("complete") is not True:
        return "coverage incomplete (%s of %s)" % (coverage.get("months_read"),
                                                    coverage.get("months_requested"))
    if system in SOCIAL and coverage.get("recovered"):
        return "historical social summary; needs a social-window capture"
    if unproven_empty(record):
        return ("clicked days answered no times and the capture declared no coverage, which "
                "proves neither an empty calendar nor a complete read")
    return None


def page_only(record, system):
    """A calendar source's capture that read the offering's text but no calendar markup."""
    return (system in CALENDAR and record is not None
            and not record.get("calendar_observed", True)
            and record.get("outcome") in ex.BASELINE_OUTCOMES)


def calendar_seen(record):
    """A capture that read its calendar in full: the only kind that closes a calendar gap."""
    return (record is not None and record.get("calendar_observed", True)
            and eligible(record, record.get("type")))


def slot_for(record, system):
    """Which baseline a capture is compared with and may replace.

    A calendar source keeps two in one record: `baseline` for its calendar and
    `page_baseline` for the offering's own text. A read that found the description but no
    calendar is a page observation: it is compared with, and may only replace, the page
    baseline, so the last calendar evidence and the calendar gap stay as they were."""
    return "page_baseline" if page_only(record, system) else "baseline"


def decide(source, record, verdict):
    """Which baseline `close` moves to this capture, and why: `(slot or None, reason)`.

    1. the capture read the source and met its declared coverage;
    2. the comparison is not `incomplete`.
    A change does not wait for review. Its findings are saved first and stay pending, gym by
    gym, until each gym resolves them, wherever the baseline has moved since."""
    system = source.get("system") or system_for(source)
    if record is None:
        return None, "no readable capture"
    blocked = why_not(record, system)
    if blocked:
        return None, blocked + "; baselines kept"
    status = (verdict or {}).get("status")
    if status not in (compare.UNCHANGED, compare.CHANGED, compare.NEW):
        reason = ((verdict or {}).get("coverage") or {}).get("reason")
        return None, "comparison %s%s; baselines kept" % (status, " (%s)" % reason if reason else "")
    slot = slot_for(record, system)
    if slot == "page_baseline":
        return slot, "%s: page text only; calendar baseline and gap kept" % status
    return slot, status


def gap_after(previous, run, record, reason):
    """The calendar gap after a run whose capture did not read the calendar in full."""
    why = ("calendar markup not observed; page text read"
           if record and not record.get("calendar_observed", True)
           and record.get("outcome") in ex.BASELINE_OUTCOMES else reason)
    return {"since_run": (previous or {}).get("since_run") or run, "last_run": run,
            "reason": why}


# ------------------------------------------------------------------------------ storage

def read_json(path, default=None):
    path = pathlib.Path(path)
    return json.loads(path.read_text()) if path.exists() else default


def write_json(path, value):
    """Write beside, flush, then rename over: a reader sees the old file or the new one."""
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w") as handle:
        handle.write(json.dumps(value, indent=1, ensure_ascii=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)


@contextlib.contextmanager
def locked(path):
    """An exclusive flock. The kernel releases it when the holder exits, crashed or not."""
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def registry_path(data):
    return pathlib.Path(data) / "sources.json"


def load(data):
    return json.loads(registry_path(data).read_text())


@contextlib.contextmanager
def editing(data, dry_run=False):
    """Lock, re-read, yield the list to change, then replace the file atomically."""
    path = registry_path(data)
    with locked(str(path) + ".lock"):
        sources = json.loads(path.read_text())
        yield sources
        if not dry_run:
            write_json(path, sources)


def index(sources):
    return {source["id"]: source for source in sources}


def run_dir(data, run):
    return pathlib.Path(data) / "runs" / run


def source_dir(data, run, sid):
    return run_dir(data, run) / "sources" / sid


def relative(data, path):
    return str(pathlib.Path(path).resolve().relative_to(pathlib.Path(data).resolve()))


def file_sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def legacy_empty(record):
    """A Rock Gym Pro calendar the November tool read as empty. That tool did not wait for
    every day cell to paint its availability, so an empty grid may be one that had not
    finished rendering: the emptiness is an unverified observation."""
    return (record is not None and record.get("type") == "rockgympro"
            and record.get("calendar_observed", True)
            and record.get("outcome") == ex.READ_EMPTY
            and bool((record.get("coverage") or {}).get("recovered")))


# Baselines whose calendar a current-tool read must re-establish before it is compared
# session by session: `dates-only` kept one session per date, `availability-unverified`
# read an empty grid without the paint check.
UNVERIFIED_SLOTS = {
    "dates-only": "legacy capture kept one session per highlighted date",
    "availability-unverified": "legacy capture read an empty grid without checking every "
                               "day cell had loaded its availability",
}


def baseline_facts(data, record, capture, run, fingerprint=None, recovered=False):
    facts = {"capture": capture, "run": run, "captured_at": record.get("captured_at"),
             "outcome": record.get("outcome"), "evidence": record.get("evidence"),
             "fingerprint": fingerprint, "sha256": file_sha(pathlib.Path(data) / capture),
             "recovered": recovered}
    if legacy_slots(record):
        # Recapture with the current tool; until then the calendar compares by date.
        facts["slot_coverage"] = "dates-only"
    elif legacy_empty(record):
        # Kept as history; a later read's sessions are reconciled, never claimed as added.
        facts["slot_coverage"] = "availability-unverified"
    if record.get("type") in SOCIAL:
        # The next capture must read back to this post before it can replace the baseline.
        posts = [post for post in record.get("posts") or [] if post.get("id")]
        facts["anchor"] = posts[0]["id"] if posts else None
    return facts


def capture_folder(data, run, sid):
    """The folder holding the source's current capture in this run: its run folder, or the
    newest `attempts/<n>/` after a forced recapture. Captures never move, so the evidence
    path in every finding stays valid."""
    folder = source_dir(data, run, sid)
    attempts = sorted((p for p in (folder / "attempts").glob("*") if p.name.isdigit()),
                      key=lambda p: int(p.name))
    return attempts[-1] if attempts else folder


def new_attempt_folder(data, run, sid):
    folder = source_dir(data, run, sid)
    current = capture_folder(data, run, sid)
    current.mkdir(parents=True, exist_ok=True)
    if not [p for p in current.iterdir() if p.is_file() and p.name not in (".lock", "verdict.json")]:
        return current
    target = folder / "attempts" / str(int(current.name) + 1 if current != folder else 1)
    target.mkdir(parents=True)
    return target


def primary_capture(folder, sid, system):
    for pattern in PRIMARY.get(system, ()):
        path = pathlib.Path(folder) / pattern.format(id=sid)
        if path.exists():
            return path
    return None


def source_record(sources, sid):
    try:
        return index(sources)[sid]
    except KeyError:
        raise RegistryError("unknown source %r: register it first" % sid)


# ------------------------------------------------------------------------------ findings

def decisions_path(data, run, gym):
    return run_dir(data, run) / "gyms" / slug(gym) / "decisions.json"


def read_records(path):
    records = read_json(path, [])
    if not isinstance(records, list):
        raise RegistryError("%s is not a list of decision records" % path)
    return records


def all_findings(data):
    """Every registry finding in every run: [(decisions.json path, record)]."""
    out = []
    for path in sorted(pathlib.Path(data).glob("runs/*/gyms/*/decisions.json")):
        for record in read_records(path):
            if isinstance(record, dict) and record.get("recorded_by") == FINDER:
                out.append((path, record))
    return out


def _digest(value):
    payload = json.dumps(value, sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(payload.encode()).hexdigest()


def _lines(text):
    seen, out = set(), []
    for line in (text or "").splitlines():
        line = " ".join(line.split())
        if line and line not in seen:
            seen.add(line)
            out.append(line)
    return out


def capture_text(data, capture):
    for suffix, text_suffix in TEXT:
        if capture and capture.endswith(suffix):
            path = pathlib.Path(data) / (capture[:-len(suffix)] + text_suffix)
            return path.read_text(errors="replace") if path.exists() else None
    return None


def text_delta(data, before, after):
    """Lines the new capture shows that the old one did not, and the reverse."""
    old, new = _lines(capture_text(data, before)), _lines(capture_text(data, after))
    return [l for l in new if l not in set(old)], [l for l in old if l not in set(new)]


def _short(text, limit=160):
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[:limit - 1] + "…"


def _session(entry):
    when = entry.get("date") or "?"
    if entry.get("start"):
        when += " " + entry["start"] + ("-" + entry["end"] if entry.get("end") else "")
    return when + (" (%s)" % entry["cohort"] if entry.get("cohort") else "")


def _listed(items, render, limit=6):
    shown = ", ".join(render(item) for item in items[:limit])
    return shown + (" and %d more" % (len(items) - limit) if len(items) > limit else "")


def _page_change(data, wrapper):
    added, removed = text_delta(data, (wrapper.get("baseline") or {}).get("capture"),
                                wrapper.get("capture"))
    summary = "Page content changed; interpretation pending."
    if added:
        summary += " New text includes “%s”." % _short(added[0])
    elif removed:
        summary += " Text no longer shown includes “%s”." % _short(removed[0])
    return summary, {"lines_added": added[:40], "lines_removed": removed[:40],
                     "lines_added_total": len(added), "lines_removed_total": len(removed)}


def _calendar_change(verdict):
    if "dates_added" in verdict:
        return _date_change(verdict)
    changes = verdict.get("changes") or {}
    added, removed, moved = (changes.get(k) or [] for k in ("added", "removed", "moved"))
    parts = []
    if added:
        parts.append("%d session(s) added: %s" % (len(added), _listed(added, _session)))
    if removed:
        parts.append("%d no longer listed: %s" % (len(removed), _listed(removed, _session)))
    if moved:
        parts.append("%d time change(s): %s" % (len(moved), _listed(moved, lambda m: "%s %s to %s" % (
            m.get("date"), (m.get("from") or {}).get("start"), (m.get("to") or {}).get("start")))))
    summary = "Calendar changed: %s." % "; ".join(parts) if parts else "Calendar changed."
    return summary, {"added": added, "removed": removed, "moved": moved,
                     "availability_changes": verdict.get("availability_changes") or []}


def _date_change(verdict):
    """A change against a baseline whose slots were never verified, stated as dates. A
    missing date carries no time: the only time known for it is the legacy capture's one."""
    new = verdict.get("dates_added") or []
    gone = verdict.get("dates_missing") or []
    added = (verdict.get("changes") or {}).get("added") or []
    parts = []
    if new:
        parts.append("%d new date(s): %s (%d session(s) read on them)" % (
            len(new), _listed(new, str), len([e for e in added if e.get("date") in new])))
    if gone:
        parts.append("%d date(s) no longer shown: %s" % (len(gone), _listed(gone, str)))
    summary = ("Calendar dates changed: %s." % "; ".join(parts) if parts else
               "Calendar changed.")
    return summary, {"dates_added": new, "dates_missing": gone, "sessions_on_new_dates": added,
                     "compared_by": "date",
                     "baseline_slot_coverage": verdict.get("slots_reason")}


def _social_change(record, verdict):
    changes = verdict.get("changes") or {}
    urls = {post.get("id"): post.get("url") for post in record.get("posts") or []}

    def render(post):
        return post.get("id") + (" (%s)" % post["published"] if post.get("published") else "")

    added = [dict(p, url=urls.get(p.get("id"))) for p in changes.get("added_posts") or []]
    edited = [dict(p, url=urls.get(p.get("id"))) for p in changes.get("edited_posts") or []]
    parts = (["%d new post(s): %s" % (len(added), _listed(added, render))] if added else []) + \
            (["%d edited post(s): %s" % (len(edited), _listed(edited, render))] if edited else [])
    summary = "Feed changed: %s." % "; ".join(parts) if parts else "Feed changed."
    return summary, {"added_posts": added, "edited_posts": edited}


def _first_read(data, system, record, wrapper):
    if page_only(record, system):
        return ("First accepted read of this offering's page. Its calendar was not shown, so "
                "no sessions are known; check the description for announcements.",
                {"lines": (record.get("page") or {}).get("lines")})
    if system in CALENDAR:
        entries = [e for e in record.get("entries") or [] if e.get("date")]
        if not entries:
            return ("First accepted read of this calendar: it shows no bookable dates. That is "
                    "an observation, not a cancellation.", {"entries": 0})
        dates = sorted(e["date"] for e in entries)
        return ("First accepted read of this calendar: %d bookable entries from %s to %s. "
                "Reconcile them with the catalogue." % (len(entries), dates[0], dates[-1]),
                {"entries": len(entries), "sample": [_session(e) for e in entries[:12]]})
    if system in SOCIAL:
        posts = [p for p in record.get("posts") or [] if p.get("id")]
        dated = sorted((p["published"] for p in posts if p.get("published")), reverse=True)
        return ("First accepted read of this account: %d post(s)%s. Reconcile them with the "
                "catalogue." % (len(posts), ", newest %s" % dated[0] if dated else ""),
                {"posts": [{"id": p["id"], "url": p.get("url"), "published": p.get("published")}
                           for p in posts[:20]]})
    lines = _lines(capture_text(data, wrapper.get("capture")))
    return ("First accepted read of this page (%d lines). Reconcile it with the catalogue."
            % len(lines), {"lines": len(lines)})


def _template(common, kind, key_parts, summary, recommended, details, provisional=False):
    key = _digest([common["source_id"], kind, common["baseline_sha256"]] + list(key_parts))
    return dict(common, ref="%s-%s-%s" % (kind.replace("_", "-"), common["source_id"], key[:10]),
                kind=kind, summary=summary, recommended=recommended, details=details,
                provisional=provisional)


def finding_templates(data, source, wrapper, record, verdict):
    """The unresolved work one ingested capture carries. Each becomes one pending record
    per cited gym: a notice, a first read to reconcile, or a change (provisional when the
    capture fell short of its coverage but still showed something new)."""
    if record is None:
        return []
    system = source.get("system") or system_for(source)
    verdict = verdict or {}
    status, changes = verdict.get("status"), verdict.get("changes") or {}
    base = wrapper.get("baseline") or {}
    common = {"source_id": source["id"], "sources": [source.get("url")],
              "capture": wrapper.get("capture"), "capture_sha256": wrapper.get("capture_sha256"),
              "baseline_capture": base.get("capture"), "baseline_sha256": base.get("sha256"),
              "compared_with": base.get("slot"), "verdict": status,
              "evidence": [p for p in (base.get("capture"), wrapper.get("capture")) if p]}
    out = []
    notice = record.get("notice")
    if notice:
        out.append(_template(
            common, "source_notice", [notice],
            "The source answered with a status notice (%s) instead of its schedule. That is "
            "not a cancellation; check the listings that cite it." % notice,
            "Open the capture and decide whether listings citing this source need review.",
            {"notice": notice}))
    # A calendar source's first page-only read sets its page baseline beside the calendar
    # baseline; page reads compare with it from the next one on. Against the calendar's own
    # render it would differ only in page furniture, and the calendar gap already says the
    # calendar went unread, so it carries no finding.
    first_page_beside_calendar = page_only(record, system) and source.get("baseline")
    slots = verdict.get("slots_to_reconcile") or []
    if slots:
        dates = sorted({entry["date"] for entry in slots})
        context = ("on dates the previous capture recorded with one session each"
                   if verdict.get("slots_reason") != "availability-unverified" else
                   "where the previous capture's empty calendar was never verified")
        summary = ("Time slots read in full for the first time: %d session(s) on %d date(s) from "
                   "%s to %s, %s. Compare these times with the catalogue; this is not a "
                   "schedule change." % (len(slots), len(dates), dates[0], dates[-1], context))
        if status == compare.INCOMPLETE:
            summary = "Partial capture (%s), so no baseline moved. Provisionally: %s" % (
                (verdict.get("coverage") or {}).get("reason") or "coverage not met", summary)
        out.append(_template(  # a confirming full read is its own record, as for changes
            common, "source_first_read",
            ["slots", "provisional" if status == compare.INCOMPLETE else "read", _digest(slots)],
            summary,
            "Reconcile these times with the catalogue's sessions, then record the outcome with "
            "refresh.py review.",
            {"slots_to_reconcile": slots[:60], "slots_total": len(slots)},
            status == compare.INCOMPLETE))
    if status == compare.NEW and first_page_beside_calendar:
        pass
    elif status == compare.NEW and wrapper.get("eligible"):
        summary, details = _first_read(data, system, record, wrapper)
        out.append(_template(
            common, "source_first_read", [verdict.get("fingerprint") or wrapper.get("capture_sha256")],
            summary, "Reconcile the capture with the catalogue, then record the outcome with "
            "refresh.py review.", details))
    elif status == compare.CHANGED or (status == compare.INCOMPLETE and any(changes.values())):
        if system in SOCIAL:
            summary, details = _social_change(record, verdict)
        elif system in CALENDAR and record.get("calendar_observed", True):
            summary, details = _calendar_change(verdict)
        else:
            summary, details = _page_change(data, wrapper)
        provisional = status == compare.INCOMPLETE
        if provisional:
            summary = "Partial capture (%s), so no baseline moved. Provisionally: %s" % (
                (verdict.get("coverage") or {}).get("reason") or "coverage not met", summary)
        out.append(_template(
            common, "source_change", [verdict.get("fingerprint") or _digest(changes)], summary,
            "Read the old and new captures; propose catalogue changes, or record why none are "
            "needed, with refresh.py review.", details, provisional))
    return out


def record_findings(data, run, source, templates):
    """Save each template as a pending record in every cited gym's decisions.json for this
    run. A ref the gym already holds, in any run, is not written again. Returns the
    (gym, ref) pairs written."""
    written = []
    gyms = source.get("gyms") or ["unassigned"]
    held = {}
    for _, record in all_findings(data) if templates else []:
        held.setdefault(record.get("gym"), set()).add(record["ref"])
    for gym in gyms if templates else []:
        missing = [t for t in templates if t["ref"] not in held.get(gym, set())]
        if not missing:
            continue
        path = decisions_path(data, run, gym)
        with locked(str(path) + ".lock"):
            records = read_records(path)
            present = {r.get("ref") for r in records if isinstance(r, dict)}
            for template in missing:
                if template["ref"] in present:
                    continue
                records.append(dict(template, gym=gym, gyms=list(gyms), run=run,
                                    status=PENDING, first_seen=now()[:10],
                                    recorded_by=FINDER, recorded_at=now(), dispositions=[]))
                written.append((gym, template["ref"]))
            write_json(path, records)
    return written


def latest_capture(data, sid):
    """The newest eligible capture of a source in any run, by ingest time."""
    best = None
    for path in pathlib.Path(data).glob("runs/*/sources/%s/verdict.json" % sid):
        wrapper = read_json(path) or {}
        if wrapper.get("eligible") and wrapper.get("capture"):
            if best is None or (wrapper.get("ingested_at") or "") > (best.get("ingested_at") or ""):
                best = wrapper
    return (best or {}).get("capture")


def shown_now(data, finding, latest):
    """Whether what a finding reported is still on the source, by its newest eligible
    capture. Informative only: a change that disappeared stays pending until resolved."""
    details = finding.get("details") or {}
    if not latest or not (details.get("lines_added") or details.get("added")):
        return None
    if latest == finding.get("capture"):
        return "still shown"
    if details.get("lines_added"):
        current = set(_lines(capture_text(data, latest)))
        hits = [line in current for line in details["lines_added"]]
    elif details.get("added"):
        try:
            record = ex.extract(str(pathlib.Path(data) / latest))
        except (OSError, ValueError):
            return None
        current = {(e.get("date"), e.get("start"), e.get("end")) for e in record.get("entries") or []}
        hits = [(e.get("date"), e.get("start"), e.get("end")) in current for e in details["added"]]
    else:
        return None
    if all(hits):
        return "still shown"
    return "no longer shown" if not any(hits) else "partly shown (%d of %d)" % (sum(hits), len(hits))


def run_of(path):
    """The run a data-relative path belongs to: `runs/<run>/...`."""
    parts = pathlib.PurePosixPath(path or "").parts
    return parts[1] if len(parts) > 2 and parts[0] == "runs" else None


def find_proposal(data, ref, run):
    """Proposal `<gym-folder>/<ref>` in run `run`, as {ref, run, file}: the gym's own
    `gyms/<gym>/proposals.json` (bare refs) first, then the run's other proposal files
    (prefixed refs). None when that run does not hold it. Refs are reused across runs, so a
    proposal is always the pair (run, ref)."""
    match = PROPOSAL_REF.match(ref or "")
    if not match:
        raise RegistryError("name the proposal as <gym-folder>/<ref>, not %r" % ref)
    folder, bare = match.groups()
    root = run_dir(data, run)
    own = root / "gyms" / folder / "proposals.json"
    others = sorted(p for p in root.rglob("*proposals.json") if p != own) if root.is_dir() else []
    for path in [own] + others:
        entries = read_json(path, []) if path.exists() else []
        for entry in entries if isinstance(entries, list) else []:
            if isinstance(entry, dict) and (entry.get("ref") == ref or
                                            (path == own and entry.get("ref") == bare)):
                return {"ref": ref, "run": run, "file": relative(data, path)}
    return None


def publication_receipts(data):
    """Production receipts by (run, proposal ref). `research/apply_record.py` appends every
    applied proposal to its package's `applied.json` as {ref, id, status, target}. A receipt
    publishes its own run's proposal only: another run that reuses the ref published
    different work."""
    data = pathlib.Path(data)
    out = {}
    for path in sorted(data.glob("runs/**/applied.json")):
        rows, rel = read_json(path, []), relative(data, path)
        for row in rows if isinstance(rows, list) else []:
            if isinstance(row, dict) and row.get("target") == "prod" and row.get("status") == "ok":
                out[(run_of(rel), row.get("ref"))] = {"listing_id": row.get("id"), "receipt": rel}
    return out


def open_findings(data, gym=None, source_id=None, include_resolved=False):
    """Unresolved findings from every run, oldest first, each with where it is shown now. A
    `proposed` finding carries its proposal and that proposal's state; it resolves when a
    production receipt records the proposal published."""
    data = pathlib.Path(data)
    latest, receipts, out = {}, None, []
    for path, record in all_findings(data):
        if (gym and record.get("gym") != gym) or (source_id and record.get("source_id") != source_id):
            continue
        status, state = record.get("status"), None
        if status == PROPOSED:
            if receipts is None:
                receipts = publication_receipts(data)
            link = record.get("proposal") or {}
            run = link.get("run") or run_of(link.get("file"))
            receipt = receipts.get((run, link.get("ref")))
            if receipt:
                state = dict(receipt, state="published")
            else:
                state = {"state": "awaiting publication"}
                elsewhere = sorted(r["receipt"] for (other, ref), r in receipts.items()
                                   if ref == link.get("ref") and other != run)
                if elsewhere:  # the same ref published other runs' work, not this proposal
                    state["same_ref_other_runs"] = elsewhere
            status = RESOLVED if receipt else PROPOSED
        if not include_resolved and status not in UNRESOLVED:
            continue
        sid = record.get("source_id")
        if sid not in latest:
            latest[sid] = latest_capture(data, sid)
        item = dict(record, status=status, file=relative(data, path),
                    shown_now=shown_now(data, record, latest[sid]))
        if state:
            item["proposal_state"] = state
        out.append(item)
    return out


def review(data, gyms, by, note, outcome="no-change", run=None, source_ids=None, refs=None,
           all_gyms=False, proposal=None, proposal_run=None):
    """Record gyms' dispositions of their findings. Each gym's record is its own.

    `no-change` resolves a finding and `held` keeps it pending with the note. `proposed` names
    the proposal that carries the work, `<gym-folder>/<ref>` (the bare ref when one gym is
    named), in the findings' own run unless `proposal_run` names a later one. The finding
    keeps that (run, ref) link and stays unresolved until a production receipt from that
    run records the proposal published.

    A disposition is bound to a capture: naming sources touches only findings recorded from
    each source's current capture in `run`, so a recapture needs its own review. Findings
    from earlier captures or runs are named by `refs`. `all_gyms` touches only records no
    gym has disposed of yet, so it never overrides a gym's own entry."""
    if outcome not in DISPOSITIONS:
        raise RegistryError("outcome must be one of %s" % ", ".join(DISPOSITIONS))
    if not gyms and not all_gyms:
        raise RegistryError("name the gym(s) the disposition is for, or --all-gyms")
    data = pathlib.Path(data)
    if outcome == "proposed":
        if not proposal:
            raise RegistryError("--outcome proposed needs --proposal: the proposal that carries "
                                "the work, as <gym-folder>/<ref>")
        if "/" not in proposal:
            if all_gyms or len(gyms) != 1:
                raise RegistryError("name the proposal as <gym-folder>/<ref> when the "
                                    "disposition covers several gyms")
            proposal = "%s/%s" % (slug(gyms[0]), proposal)
        if not PROPOSAL_REF.match(proposal):
            raise RegistryError("name the proposal as <gym-folder>/<ref>, not %r" % proposal)
    elif proposal or proposal_run:
        raise RegistryError("--proposal goes with --outcome proposed only")
    findings = all_findings(data)
    if refs:
        targets = [(path, record) for path, record in findings if record["ref"] in refs]
        missing = set(refs) - {record["ref"] for _, record in targets}
        if missing:
            raise RegistryError("no finding %s" % ", ".join(sorted(missing)))
    else:
        if not run:
            raise RegistryError("name the run whose captures were reviewed, or the finding refs")
        registry = index(load(data))
        root = run_dir(data, run) / "sources"
        sids = source_ids or sorted(
            p.name for p in root.glob("*") if p.name in registry and
            (all_gyms or set(gyms) & set(registry[p.name].get("gyms") or [])))
        current = {}
        for sid in sids:
            wrapper = read_json(root / sid / "verdict.json")
            if not wrapper or not wrapper.get("capture"):
                raise RegistryError("%s has no ingested capture in %s" % (sid, run))
            current[sid] = wrapper.get("capture_sha256")
        targets = [(path, record) for path, record in findings
                   if record.get("run") == run and record.get("source_id") in current
                   and record.get("capture_sha256") == current[record["source_id"]]]
    targets = [(path, record) for path, record in targets
               if ((all_gyms and not record.get("dispositions")) or record.get("gym") in (gyms or ()))
               and (refs is not None or record.get("status") == PENDING)]
    link = None
    if outcome == "proposed" and targets:
        runs = sorted({record.get("run") for _, record in targets})
        if proposal_run is None and len(runs) > 1:
            raise RegistryError("these findings come from runs %s: name the run whose proposal "
                                "carries the work with --proposal-run" % ", ".join(runs))
        if proposal_run is not None and (not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", proposal_run)
                                         or not run_dir(data, proposal_run).is_dir()):
            raise RegistryError("no run %r under runs/" % proposal_run)
        proposal_run = proposal_run or runs[0]
        if proposal_run < runs[-1]:
            raise RegistryError("run %s is before the finding's run %s: a proposal drafted before "
                                "a change was seen cannot carry it" % (proposal_run, runs[-1]))
        link = find_proposal(data, proposal, proposal_run)
        if link is None:
            raise RegistryError("no proposal %s in run %s's proposal files" % (proposal, proposal_run))
    done = []
    for path in sorted({path for path, _ in targets}):
        wanted = {record["ref"] for p, record in targets if p == path}
        with locked(str(path) + ".lock"):
            records = read_records(path)
            for record in records:
                if not isinstance(record, dict) or record.get("ref") not in wanted:
                    continue
                if record.get("status") != PENDING and refs is None:
                    continue
                disposition = {"at": now(), "by": by, "outcome": outcome, "note": note,
                               "capture_sha256": record.get("capture_sha256")}
                if link:
                    disposition["proposal"] = record["proposal"] = link
                else:
                    record.pop("proposal", None)
                record.setdefault("dispositions", []).append(disposition)
                record["status"] = DISPOSITIONS[outcome]
                done.append({"gym": record.get("gym"), "ref": record["ref"],
                             "status": record["status"], "proposal": link})
            write_json(path, records)
    return done


# ---------------------------------------------------------------------------- a run

def ingest(data, run, sid, by):
    """Compare the source's current capture in this run with the baseline it belongs to,
    write `verdict.json`, and save any finding it carries. Never moves a baseline."""
    data = pathlib.Path(data)
    source = source_record(load(data), sid)
    system = source.get("system") or system_for(source)
    folder = capture_folder(data, run, sid)
    path = primary_capture(folder, sid, system)
    if path is None:
        raise RegistryError("no %s capture for %s in %s (expected %s)" % (
            system, sid, folder, " or ".join(PRIMARY[system]).format(id=sid)))
    record = ex.extract(str(path))
    slot = slot_for(record, system)
    base = source.get(slot)
    before = ex.extract(str(data / base["capture"])) if base else None
    verdict = compare.compare_source(before, record)
    unverified = (base or {}).get("slot_coverage")
    if unverified in UNVERIFIED_SLOTS and not (record.get("coverage") or {}).get("recovered"):
        verdict = reconcile_unverified(verdict, before, record, unverified)
    out = {"source_id": sid, "gyms": source.get("gyms") or [],
           "capture": relative(data, path), "capture_sha256": file_sha(path),
           "baseline": {"slot": slot, "capture": (base or {}).get("capture"),
                        "sha256": (base or {}).get("sha256"), "run": (base or {}).get("run")},
           "captured_by": by, "ingested_at": now(),
           "outcome": record.get("outcome"), "evidence": record.get("evidence"),
           "calendar_observed": record.get("calendar_observed") if system in CALENDAR else None,
           "eligible": eligible(record, system), "blocked": why_not(record, system),
           "notice": record.get("notice"), "verdict": verdict}
    templates = finding_templates(data, source, out, record, verdict)
    out["findings"] = [template["ref"] for template in templates]
    write_json(source_dir(data, run, sid) / "verdict.json", out)
    record_findings(data, run, source, templates)
    return out


def capture(data, run, sid, by, session, force=False):
    """Run the source's capture tool into its run folder, then ingest. A source already
    captured eligibly in this run is reused, so a shared source is read once per run; a
    forced recapture writes a new attempt folder and leaves the earlier capture in place."""
    data = pathlib.Path(data)
    source = source_record(load(data), sid)
    system = source.get("system") or system_for(source)
    root = source_dir(data, run, sid)
    root.mkdir(parents=True, exist_ok=True)
    with locked(root / ".lock"):
        existing = read_json(root / "verdict.json")
        if existing and existing.get("eligible") and not force:
            existing["reused"] = True
            return existing
        folder = new_attempt_folder(data, run, sid)
        args = [sys.executable, str(TOOLS / TOOL[system]), session, str(folder), sid, source["url"]]
        if system in CALENDAR:
            args.append(str(MONTHS_REQUESTED))
        if system in SOCIAL:
            args += [str(SOCIAL_WINDOW), (source.get("baseline") or {}).get("anchor") or ""]
        result = subprocess.run(args, capture_output=True, text=True, timeout=900)
        if primary_capture(folder, sid, system) is None:
            failure = {"source_id": sid, "gyms": source.get("gyms") or [], "capture": None,
                       "captured_by": by, "ingested_at": now(), "outcome": ex.FAILED,
                       "eligible": False, "blocked": "capture tool wrote no capture",
                       "tool_exit": result.returncode,
                       "tool_stderr": result.stderr[-2000:], "verdict": None, "findings": []}
            write_json(root / "verdict.json", failure)
            return failure
        return ingest(data, run, sid, by)


def plan(data, run):
    """What `close` would do for each source captured in the run. Reads only."""
    data = pathlib.Path(data)
    registry = index(load(data))
    rows = {}
    root = run_dir(data, run) / "sources"
    for folder in sorted(root.glob("*")) if root.exists() else []:
        if not folder.is_dir():
            continue
        sid = folder.name
        source = registry.get(sid)
        wrapper = read_json(folder / "verdict.json")
        if source is None:
            rows[sid] = {"slot": None, "reason": "not in the registry; register it"}
            continue
        if wrapper is None:
            rows[sid] = {"slot": None, "reason": "captured but not ingested"}
            continue
        capture_path = wrapper.get("capture")
        record = ex.extract(str(data / capture_path)) if capture_path else None
        verdict = wrapper.get("verdict") or {}
        slot, reason = decide(source, record, verdict)
        rows[sid] = {"slot": slot, "reason": reason, "capture": capture_path, "record": record,
                     "verdict": verdict, "source": source, "gyms": source.get("gyms") or [],
                     "templates": finding_templates(data, source, wrapper, record, verdict)}
    return rows


def recapture_queue(sources):
    """Calendar sources whose baseline a current-tool read must re-establish."""
    return [{"source_id": source["id"], "gyms": source.get("gyms") or [],
             "capture": source["baseline"]["capture"], "since_run": source["baseline"]["run"],
             "slot_coverage": source["baseline"]["slot_coverage"],
             "why": UNVERIFIED_SLOTS[source["baseline"]["slot_coverage"]]}
            for source in sources
            if (source.get("baseline") or {}).get("slot_coverage") in UNVERIFIED_SLOTS]


def _slot_key(entry):
    return (entry.get("date"), entry.get("start"), entry.get("end"), entry.get("cohort"))


def reconcile_unverified(verdict, before, current, coverage):
    """Read a current-tool comparison against a baseline whose slots were never verified.

    `dates-only`: compare dates. A date the baseline lacked is an added date; a date it had
    that the current read no longer shows is a missing date (only a complete read reports
    removals at all). Sessions on dates both saw are never added, removed or moved: the new
    ones go to `slots_to_reconcile`, and the baseline's single slot disappearing proves
    nothing. `availability-unverified`: the baseline's emptiness is unproven, so every
    session read now goes to `slots_to_reconcile` and none is called added."""
    changes = dict(verdict.get("changes") or {})
    added = list(changes.get("added") or [])
    removed = list(changes.get("removed") or [])
    moved = list(changes.get("moved") or [])
    seen = {e.get("date") for e in before.get("entries") or [] if e.get("date")}
    now_dates = {e.get("date") for e in current.get("entries") or [] if e.get("date")}
    known = {_slot_key(e) for e in before.get("entries") or []}
    # Slots come from the capture itself, not from the verdict's changes: a partial
    # comparison carries additions only, so a read whose times all shifted would otherwise
    # leave nothing behind.
    observed = [e for e in current.get("entries") or [] if _slot_key(e) not in known]

    if coverage == "availability-unverified":
        slots, added, removed = observed, [], []
        note = ("baseline's empty calendar is unverified: %d session(s) read now are listed "
                "to reconcile, not as added" % len(slots))
    else:
        slots = [e for e in observed if e.get("date") in seen or not e.get("date")]
        added = [e for e in added if e.get("date") and e.get("date") not in seen]
        dropped = [e for e in removed if e.get("date") in now_dates]
        removed = [e for e in removed if e.get("date") not in now_dates]
        note = ("baseline recorded one session per date: compared by date; %d session(s) on "
                "dates it saw are listed to reconcile, %d of its slot(s) on dates still shown "
                "are not called removed" % (len(slots), len(dropped)))
    dates_added = sorted({e.get("date") for e in added})
    dates_missing = sorted({e.get("date") for e in removed})
    view = dict(verdict, changes=dict(changes, added=added, removed=removed, moved=[]),
                slots_to_reconcile=slots, slots_reason=coverage,
                dates_added=dates_added, dates_missing=dates_missing,
                notes=list(verdict.get("notes") or []) + [note])
    left = added or removed
    if view.get("status") == compare.CHANGED and not left:
        view["status"] = compare.UNCHANGED
    if view.get("status") == compare.INCOMPLETE:
        view["provisional"] = bool(added or slots)
    return view


def calendar_gaps(sources):
    return [dict(gap, source_id=source["id"], gyms=source.get("gyms") or [])
            for source in sources for gap in [source.get("calendar_gap")] if gap]


def close(data, run, dry_run=False):
    """The run's last registry step. Every finding is saved first, again if a collector's
    edit dropped one; then each eligible capture replaces the baseline it was compared with.
    Records `last_attempt` and the calendar gap for every source captured in the run."""
    data = pathlib.Path(data)
    rows = plan(data, run)
    saved = {}
    for sid, row in rows.items():
        if not row.get("templates"):
            continue
        if not dry_run:
            try:
                record_findings(data, run, row["source"], row["templates"])
            except (OSError, ValueError, RegistryError) as exc:
                row["slot"], row["reason"] = None, "findings not saved (%s); baselines kept" % exc
                continue
        saved[sid] = [template["ref"] for template in row["templates"]]
    results = {}
    with editing(data, dry_run=dry_run) as sources:
        registry = index(sources)
        for sid, row in rows.items():
            source = registry.get(sid)
            if source is None or "capture" not in row:
                results[sid] = {"advanced": None, "reason": row["reason"], "verdict": None,
                                "findings": []}
                continue
            record, verdict = row["record"] or {}, row["verdict"]
            system = source.get("system") or system_for(source)
            source["last_attempt"] = {
                "run": run, "capture": row["capture"], "captured_at": record.get("captured_at"),
                "outcome": record.get("outcome", ex.FAILED), "evidence": record.get("evidence"),
                "calendar_observed": record.get("calendar_observed") if system in CALENDAR else None,
                "verdict": verdict.get("status"), "findings": saved.get(sid, [])}
            if row["slot"]:
                source[row["slot"]] = baseline_facts(data, record, row["capture"], run,
                                                     verdict.get("fingerprint"))
                if row["slot"] == "baseline":
                    source["ineligible"] = None
            if system in CALENDAR:
                closed = row["slot"] == "baseline" and calendar_seen(record)
                source["calendar_gap"] = None if closed else gap_after(
                    source.get("calendar_gap"), run, row["record"], row["reason"])
            results[sid] = {"advanced": row["slot"], "reason": row["reason"],
                            "verdict": verdict.get("status"), "findings": saved.get(sid, [])}
        gaps = calendar_gaps(sources)
        queue = recapture_queue(sources)
    pending = [{k: f.get(k) for k in ("ref", "gym", "run", "kind", "status", "summary", "capture",
                                       "shown_now", "proposal", "proposal_state", "file")}
               for f in open_findings(data)]
    if not dry_run:
        write_json(run_dir(data, run) / "close.json",
                   {"closed_at": now(), "sources": results, "calendar_gaps": gaps,
                    "recapture": queue,
                    "pending_findings": pending})
    return results, pending, gaps


def register(data, url, gyms, kind, sid=None, origin="refresh discovery", dry_run=False):
    """Add a source found during a run. Returns (record, created)."""
    target = normalise_url(url)
    with editing(data, dry_run=dry_run) as sources:
        for source in sources:
            urls = [source.get("url")] + [a.get("url") for a in source.get("aliases") or []]
            if target in {normalise_url(u) for u in urls if u}:
                return source, False
        ids = {source["id"] for source in sources}
        if sid is None:
            base = "%s-%s" % (slug(gyms[0] if gyms else "shared"), slug(kind))
            sid, n = base, 1
            while sid in ids:
                n += 1
                sid = "%s-%d" % (base, n)
        elif sid in ids:
            raise RegistryError("source id %r already exists" % sid)
        record = {"id": sid, "url": url, "type": kind, "gyms": list(gyms), "active": True,
                  "origin": origin}
        record.update(system=system_for(record), aliases=[], baseline=None, ineligible=None,
                      last_attempt=None)
        if record["system"] in CALENDAR:
            record.update(page_baseline=None, calendar_gap=None)
        record["coverage_contract"] = CONTRACT[record["system"]]
        sources.append(record)
        return record, True
