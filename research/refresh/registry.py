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
PENDING, RESOLVED = "pending", "resolved"
DISPOSITIONS = {"proposed": RESOLVED, "no-change": RESOLVED, "held": PENDING}


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

def eligible(record, system):
    """A capture may become a baseline only when it read the source and met its declared
    coverage. Social coverage must be declared by a social-window capture: a historical
    summary whose coverage was reconstructed afterwards never qualifies."""
    coverage = record.get("coverage") or {}
    if record.get("outcome") not in ex.BASELINE_OUTCOMES or coverage.get("complete") is not True:
        return False
    if system in SOCIAL and coverage.get("recovered"):
        return False
    return True


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
    return None


def page_only(record, system):
    """A calendar source's capture that read the offering's text but no calendar markup."""
    return (system in CALENDAR and record is not None
            and not record.get("calendar_observed", True)
            and record.get("outcome") in ex.BASELINE_OUTCOMES)


def calendar_seen(record):
    """A capture that read its calendar in full: the only kind that closes a calendar gap."""
    return (record is not None and record.get("calendar_observed", True)
            and record.get("outcome") in ex.BASELINE_OUTCOMES
            and (record.get("coverage") or {}).get("complete") is True)


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


def baseline_facts(data, record, capture, run, fingerprint=None, recovered=False):
    facts = {"capture": capture, "run": run, "captured_at": record.get("captured_at"),
             "outcome": record.get("outcome"), "evidence": record.get("evidence"),
             "fingerprint": fingerprint, "sha256": file_sha(pathlib.Path(data) / capture),
             "recovered": recovered}
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
    calendar = source.get("baseline") if page_only(record, system) else None
    if status == compare.NEW and wrapper.get("eligible") and calendar:
        # The offering's text was last seen above its calendar. Only text that calendar read
        # did not show is news; the missing calendar itself is the source's calendar gap.
        added, _ = text_delta(data, calendar.get("capture"), wrapper.get("capture"))
        if added:
            out.append(_template(
                dict(common, evidence=[calendar.get("capture"), wrapper.get("capture")]),
                "source_change", [_digest(added)],
                "Calendar not shown this run, and the offering page has text its last calendar "
                "read did not: “%s”. Interpretation pending." % _short(added[0]),
                "Read the old and new captures; propose catalogue changes, or record why none "
                "are needed, with refresh.py review.",
                {"lines_added": added[:40], "lines_added_total": len(added),
                 "compared_with_calendar_capture": calendar.get("capture")}))
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


def open_findings(data, gym=None, source_id=None, include_resolved=False):
    """Pending findings from every run, oldest first, each with where it is shown now."""
    data = pathlib.Path(data)
    latest, out = {}, []
    for path, record in all_findings(data):
        if not include_resolved and record.get("status") != PENDING:
            continue
        if (gym and record.get("gym") != gym) or (source_id and record.get("source_id") != source_id):
            continue
        sid = record.get("source_id")
        if sid not in latest:
            latest[sid] = latest_capture(data, sid)
        out.append(dict(record, file=relative(data, path),
                        shown_now=shown_now(data, record, latest[sid])))
    return out


def review(data, gyms, by, note, outcome="no-change", run=None, source_ids=None, refs=None,
           all_gyms=False, ref=None):
    """Record gyms' dispositions of pending findings. `proposed` and `no-change` resolve a
    finding; `held` keeps it pending with the note. Each gym's record is its own.

    A disposition is bound to a capture: naming sources touches only findings recorded from
    each source's current capture in `run`, so a recapture needs its own review. Findings
    from earlier captures or runs are named by `refs`. `all_gyms` touches only records no
    gym has disposed of yet, so it never overrides a gym's own entry."""
    if outcome not in DISPOSITIONS:
        raise RegistryError("outcome must be one of %s" % ", ".join(DISPOSITIONS))
    if not gyms and not all_gyms:
        raise RegistryError("name the gym(s) the disposition is for, or --all-gyms")
    data = pathlib.Path(data)
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
               if (all_gyms and not record.get("dispositions")) or record.get("gym") in (gyms or ())]
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
                record.setdefault("dispositions", []).append(
                    {"at": now(), "by": by, "outcome": outcome, "note": note, "ref": ref,
                     "capture_sha256": record.get("capture_sha256")})
                record["status"] = DISPOSITIONS[outcome]
                done.append({"gym": record.get("gym"), "ref": record["ref"],
                             "status": record["status"]})
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
    pending = [{k: f.get(k) for k in ("ref", "gym", "run", "kind", "summary", "capture",
                                       "shown_now", "file")} for f in open_findings(data)]
    if not dry_run:
        write_json(run_dir(data, run) / "close.json",
                   {"closed_at": now(), "sources": results, "calendar_gaps": gaps,
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
