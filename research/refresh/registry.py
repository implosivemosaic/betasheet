"""The refresh registry: one record per source in `sources.json`, and the one rule that moves
a baseline. See REGISTRY.md.

`extract.py` says what a capture read and `compare.py` what changed; this module decides which
capture is each source's baseline. It is the only code that writes `sources.json`.
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
# Fields the November registry used, now held by `baseline`, `ineligible` and `last_attempt`.
FOLDED = ("last_copy", "fingerprint", "last_checked", "coverage_note", "last_attempt")
# Query parameters that decorate a URL without selecting different content.
DECORATION = re.compile(r"^(date|month|utm_[a-z]+|fbclid|gclid|igsh|igshid|__cft__.*|__tn__)$",
                        re.I)
# The file a capture tool writes for each system; `extract()` reads it.
PRIMARY = {"rockgympro": ("{id}.rgp.json",), "redpoint": ("{id}.rphq.json",),
           "page": ("{id}.meta.json",), "instagram": ("ig-{id}.md",),
           "facebook": ("fb-{id}.md",)}


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
    if name.startswith("ig-") and name.endswith(".md"):
        return "instagram"
    if name.startswith("fb-") and name.endswith(".md"):
        return "facebook"
    return None


def system_for(source):
    """Which extractor reads a source, from its type and URL."""
    kind = source.get("type")
    if kind in SOCIAL:
        return kind
    parts = urllib.parse.urlsplit(source.get("url") or "")
    host = (parts.hostname or "").lower()
    if host.endswith("rockgympro.com") and re.search(r"(^|&)(bo|offering_guid)=", parts.query):
        return "rockgympro"
    if host.endswith("rphq.com") and "/programs/" in parts.path:
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


def decide(source, record, verdict, reviews, capture_sha):
    """Whether `close` moves this source's baseline to the run's capture, and why.

    1. the capture read the source and met its coverage (an incomplete capture never moves
       a baseline, whatever its comparison says);
    2. the comparison is not `incomplete`;
    3. the verdict is `unchanged`, or every gym citing the source reviewed this capture
       (a review is bound to the capture file's hash, so a recapture needs a new review).
    """
    system = source.get("system") or system_for(source)
    if record is None:
        return False, "no readable capture"
    blocked = why_not(record, system)
    if blocked:
        return False, blocked + "; baseline kept"
    status = (verdict or {}).get("status")
    if status not in (compare.UNCHANGED, compare.CHANGED, compare.NEW):
        reason = ((verdict or {}).get("coverage") or {}).get("reason")
        return False, "comparison %s%s; baseline kept" % (status, " (%s)" % reason if reason else "")
    if status == compare.UNCHANGED:
        return True, status
    reviewed = {gym for gym, mark in (reviews or {}).items() if mark.get("sha256") == capture_sha}
    gyms = source.get("gyms") or []
    if "*" in reviewed:
        missing = []
    elif gyms:
        missing = [gym for gym in gyms if gym not in reviewed]
    else:
        missing = [] if reviewed else ["any reviewer"]
    if missing:
        return False, "%s, awaiting review by %s" % (status, ", ".join(missing))
    return True, status


# ------------------------------------------------------------------------------ storage

def read_json(path, default=None):
    path = pathlib.Path(path)
    return json.loads(path.read_text()) if path.exists() else default


def write_json(path, value):
    """Write beside, flush, then rename over: a reader sees the old file or the new one."""
    path = pathlib.Path(path)
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
    return {"capture": capture, "run": run, "captured_at": record.get("captured_at"),
            "outcome": record.get("outcome"), "evidence": record.get("evidence"),
            "fingerprint": fingerprint, "sha256": file_sha(pathlib.Path(data) / capture),
            "recovered": recovered}


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


# ---------------------------------------------------------------------------- a run

def ingest(data, run, sid, by):
    """Compare the capture saved in the source's run folder with its baseline, and write
    `verdict.json` beside it. Writes nothing to the registry."""
    data = pathlib.Path(data)
    source = source_record(load(data), sid)
    system = source.get("system") or system_for(source)
    folder = source_dir(data, run, sid)
    path = primary_capture(folder, sid, system)
    if path is None:
        raise RegistryError("no %s capture for %s in %s (expected %s)" % (
            system, sid, folder, " or ".join(PRIMARY[system]).format(id=sid)))
    record = ex.extract(str(path))
    baseline = source.get("baseline")
    before = ex.extract(str(data / baseline["capture"])) if baseline else None
    verdict = compare.compare_source(before, record)
    out = {"source_id": sid, "gyms": source.get("gyms") or [],
           "capture": relative(data, path),
           "baseline": baseline["capture"] if baseline else None,
           "captured_by": by, "ingested_at": now(),
           "outcome": record.get("outcome"), "evidence": record.get("evidence"),
           "eligible": eligible(record, system), "blocked": why_not(record, system),
           "notice": record.get("notice"), "verdict": verdict}
    write_json(folder / "verdict.json", out)
    return out


def archive_attempt(folder):
    """Move the folder's current capture into `attempts/<n>/`, keeping it as evidence."""
    current = [p for p in folder.iterdir() if p.name not in (".lock", "attempts")]
    if not current:
        return None
    attempts = folder / "attempts"
    n = 1 + max([int(p.name) for p in attempts.glob("*") if p.name.isdigit()] or [0])
    target = attempts / str(n)
    target.mkdir(parents=True)
    for path in current:
        os.replace(path, target / path.name)
    return target


def capture(data, run, sid, by, session, force=False):
    """Run the source's capture tool into its run folder, then ingest. A source already
    captured eligibly in this run is reused, so a shared source is read once per run."""
    data = pathlib.Path(data)
    source = source_record(load(data), sid)
    system = source.get("system") or system_for(source)
    if system in SOCIAL:
        raise RegistryError("%s is read in Keith's browser: save %s into %s, then ingest" % (
            sid, PRIMARY[system][0].format(id=sid), source_dir(data, run, sid)))
    folder = source_dir(data, run, sid)
    folder.mkdir(parents=True, exist_ok=True)
    with locked(folder / ".lock"):
        existing = read_json(folder / "verdict.json")
        if existing and existing.get("eligible") and not force:
            existing["reused"] = True
            return existing
        archive_attempt(folder)
        tool = {"page": "page.py", "rockgympro": "rgp.py", "redpoint": "rphq.py"}[system]
        args = [sys.executable, str(TOOLS / tool), session, str(folder), sid, source["url"]]
        if system in CALENDAR:
            args.append(str(MONTHS_REQUESTED))
        result = subprocess.run(args, capture_output=True, text=True, timeout=900)
        if primary_capture(folder, sid, system) is None:
            failure = {"source_id": sid, "gyms": source.get("gyms") or [], "capture": None,
                       "captured_by": by, "ingested_at": now(), "outcome": ex.FAILED,
                       "eligible": False, "blocked": "capture tool wrote no capture",
                       "tool_exit": result.returncode,
                       "tool_stderr": result.stderr[-2000:], "verdict": None}
            write_json(folder / "verdict.json", failure)
            return failure
        return ingest(data, run, sid, by)


def review(data, run, gym, by, note, source_ids=None, all_gyms=False):
    """Record that `gym`'s write-up covers these sources' verdicts. Without `source_ids`,
    every source citing the gym that was captured in this run."""
    data = pathlib.Path(data)
    registry = index(load(data))
    folder = run_dir(data, run) / "sources"
    if source_ids:
        targets = list(source_ids)
    else:
        targets = sorted(p.name for p in folder.glob("*")
                         if p.name in registry and gym in (registry[p.name].get("gyms") or []))
    marked = []
    for sid in targets:
        if sid not in registry:
            raise RegistryError("unknown source %r" % sid)
        if not all_gyms and gym not in (registry[sid].get("gyms") or []):
            raise RegistryError("%s is not cited by %s; use --all-gyms for a shared owner" % (
                sid, gym))
        wrapper = read_json(folder / sid / "verdict.json")
        if not wrapper or not wrapper.get("capture"):
            raise RegistryError("%s has no ingested capture in %s" % (sid, run))
        with locked(folder / sid / ".lock"):
            reviews = read_json(folder / sid / "review.json", {})
            reviews["*" if all_gyms else gym] = {
                "at": now(), "by": by, "note": note, "capture": wrapper["capture"],
                "sha256": file_sha(data / wrapper["capture"])}
            write_json(folder / sid / "review.json", reviews)
        marked.append(sid)
    return marked


def plan(data, run):
    """What `close` would do for each source captured in the run. Reads only."""
    data = pathlib.Path(data)
    registry = index(load(data))
    rows = {}
    for folder in sorted((run_dir(data, run) / "sources").glob("*")):
        if not folder.is_dir():
            continue
        sid = folder.name
        source = registry.get(sid)
        wrapper = read_json(folder / "verdict.json")
        reviews = read_json(folder / "review.json", {})
        if source is None:
            rows[sid] = {"advance": False, "reason": "not in the registry; register it"}
            continue
        if wrapper is None:
            rows[sid] = {"advance": False, "reason": "captured but not ingested"}
            continue
        capture_path = wrapper.get("capture")
        record = ex.extract(str(data / capture_path)) if capture_path else None
        sha = file_sha(data / capture_path) if capture_path else None
        verdict = wrapper.get("verdict") or {}
        advance, reason = decide(source, record, verdict, reviews, sha)
        rows[sid] = {"advance": advance, "reason": reason, "capture": capture_path,
                     "record": record, "verdict": verdict, "gyms": source.get("gyms") or [],
                     "reviews": sorted(reviews), "notice": (record or {}).get("notice")}
    return rows


def close(data, run, dry_run=False):
    """The run's last step and the only place a baseline moves. Records `last_attempt` for
    every source captured in the run; advances `baseline` where `decide` allows."""
    data = pathlib.Path(data)
    results, findings = {}, []
    with editing(data, dry_run=dry_run) as sources:
        registry = index(sources)
        for sid, row in plan(data, run).items():
            source = registry.get(sid)
            record, verdict = row.get("record"), row.get("verdict") or {}
            if source is not None and "capture" in row:
                source["last_attempt"] = {
                    "run": run, "capture": row["capture"],
                    "captured_at": (record or {}).get("captured_at"),
                    "outcome": (record or {}).get("outcome", ex.FAILED),
                    "evidence": (record or {}).get("evidence"),
                    "verdict": verdict.get("status")}
                if row["advance"]:
                    source["baseline"] = baseline_facts(data, record, row["capture"], run,
                                                        verdict.get("fingerprint"))
                    source["ineligible"] = None
            if row.get("notice"):
                findings.append({"source_id": sid, "notice": row["notice"],
                                 "evidence": [row["capture"]]})
            results[sid] = {"advanced": row["advance"], "reason": row["reason"],
                            "verdict": verdict.get("status")}
    if not dry_run:
        write_json(run_dir(data, run) / "close.json",
                   {"closed_at": now(), "sources": results, "findings": findings})
    return results, findings


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
        record.update(system=system_for(record), aliases=[], baseline=None,
                      ineligible=None, last_attempt=None)
        record["coverage_contract"] = CONTRACT[record["system"]]
        sources.append(record)
        return record, True
