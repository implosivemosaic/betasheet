#!/usr/bin/env python3
"""Mechanical steps of the weekly refresh. Judgment stays with the researcher;
see docs/weekly-refresh.md for the whole run.

The source list (DATA/sources.json) is last week's and stays read-only during a run. Work is split
into parts: one per gym, plus "shared" for sources several gyms share (such as the OCF calendar).
Each part writes only into its own folder, runs/<date>/gyms/<part>/, so agents never share a file.
`merge` then builds the new source list and the run's proposals from all the parts.

  research/run.py start [DATE]            create runs/DATE/ and its part folders
  research/run.py parts                   list the parts, their gyms and source counts
  research/run.py fetch PART [PART...]    read a part's "box" sources; fingerprint; save changed text
  research/run.py record PART SOURCE FILE same, for a "browser" source whose text you saved
  research/run.py done PART            mark a part finished and ready for Keith's review
  research/run.py status                  what each part has checked so far
  research/run.py merge                   new sources.json + run proposals + duplicate check
  research/run.py dev                     local dev database = newest production snapshot

DATA defaults to ../betasheet-data/betasheet next to this repo; the run is the newest folder unless
--run DATE is given.
"""
import argparse, concurrent.futures, datetime, difflib, hashlib, html, json, os, re, sys, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
DATA = Path(os.environ.get("DATA", HERE.parents[1] / "betasheet-data" / "betasheet"))
SOURCES = DATA / "sources.json"
UA = "Mozilla/5.0 (compatible; BetaSheet research; +https://betasheet.ca/about)"

def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")

def part_of(source):
    return slug(source["gyms"][0]) if len(source["gyms"]) == 1 else "shared"

def read_json(path, default):
    return json.loads(path.read_text()) if path.exists() else default

def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=1) + "\n")

def sources():
    return read_json(SOURCES, [])

def run_dir(name=None):
    if name:
        return DATA / "runs" / name
    runs = sorted((DATA / "runs").glob("20*"))
    if not runs:
        sys.exit("no run folder yet: research/run.py start")
    return runs[-1]

def readable(raw):
    """Visible text of a page, one line per block, whitespace tidied. Scripts, styles,
    hidden inputs and tokens never reach the fingerprint."""
    t = re.sub(r"(?is)<(script|style|noscript|svg|template|head)\b.*?</\1>", " ", raw)
    t = re.sub(r"(?i)<br\s*/?>|</(p|div|li|tr|h[1-6]|td|th|section|article|option|dt|dd)>", "\n", t)
    t = re.sub(r"<[^>]+>", " ", t)
    t = html.unescape(t)
    lines = (re.sub(r"[ \t\r\xa0​]+", " ", l).strip() for l in t.split("\n"))
    return "\n".join(l for l in lines if l) + "\n"

def instagram_posts(text):
    """Post and reel IDs visible on a saved profile page."""
    return sorted({m for pair in re.findall(r"instagram\.com/(?:p|reel)/([\w-]+)|/(?:p|reel)/([\w-]+)/", text) for m in pair if m})

def check(source, text, rd, part, today):
    """Compare a source's text with last week's; on change save the text and a diff in the part
    folder. Returns the check record; the source list itself is not touched."""
    fp = hashlib.sha256(text.encode()).hexdigest()[:16]
    rec = {"id": source["id"], "url": source["url"], "type": source["type"], "checked": today, "fingerprint": fp}
    if fp == source.get("fingerprint"):
        rec["status"] = "unchanged"
        return rec
    rec["status"] = "new" if not source.get("fingerprint") else "changed"
    pages = rd / "gyms" / part / "pages"
    pages.mkdir(parents=True, exist_ok=True)
    (pages / f"{source['id']}.txt").write_text(text)
    rec["copy"] = f"runs/{rd.name}/gyms/{part}/pages/{source['id']}.txt"
    prev = DATA / source["last_copy"] if source.get("last_copy") else None
    if prev and prev.exists():
        diff = difflib.unified_diff(prev.read_text().splitlines(), text.splitlines(), "last", "now", lineterm="", n=1)
        (pages / f"{source['id']}.diff").write_text("\n".join(diff) + "\n")
    if source["type"] == "instagram":
        seen = set(source.get("seen_posts", []))
        posts = instagram_posts(text)
        rec["posts"] = posts
        rec["new_posts"] = [p for p in posts if p not in seen]
    return rec

def save_checks(rd, part, recs):
    path = rd / "gyms" / part / "checks.json"
    old = {r["id"]: r for r in read_json(path, [])}
    old.update({r["id"]: r for r in recs})
    write_json(path, sorted(old.values(), key=lambda r: r["id"]))

def fetch_text(source):
    req = urllib.request.Request(source["url"], headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return readable(r.read().decode(r.headers.get_content_charset() or "utf-8", "replace"))

def cmd_start(a):
    name = a.date or datetime.date.today().isoformat()
    rd = run_dir(name)
    for part in sorted({part_of(s) for s in sources() if s["active"]}):
        for f, empty in (("proposals.json", []), ("source-changes.json", {"add": [], "update": [], "deactivate": []})):
            if not (rd / "gyms" / part / f).exists():
                write_json(rd / "gyms" / part / f, empty)
    if not (rd / "report.md").exists():
        (rd / "report.md").write_text(f"# Weekly refresh {name}\n\n## Checked\n\n## New\n\n## Changed\n\n"
                                      "## Possible duplicates\n\n## Uncertain or blocked\n\n## Source list changes\n")
    for f in ("proposals.json", "applied.json"):
        if not (rd / f).exists():
            write_json(rd / f, [])
    print(rd)

def cmd_parts(a):
    by = {}
    for s in sources():
        if s["active"]:
            p = by.setdefault(part_of(s), {"gyms": set(), "box": 0, "browser": 0})
            p["gyms"].update(s["gyms"])
            p[s["fetch"]] += 1
    for part, p in sorted(by.items()):
        gyms = "several gyms" if part == "shared" else ", ".join(sorted(p["gyms"]))
        print(f"{part}\tbox {p['box']}\tbrowser {p['browser']}\t{gyms}")

def cmd_fetch(a):
    rd, today = run_dir(a.run), datetime.date.today().isoformat()
    for part in a.parts:
        todo = [s for s in sources() if s["active"] and s["fetch"] == "box" and part_of(s) == part]
        if not todo:
            print(f"{part}: no box sources (check the name with `parts`)")
            continue
        def work(s):
            try:
                return check(s, fetch_text(s), rd, part, today)
            except Exception as e:
                return {"id": s["id"], "url": s["url"], "type": s["type"], "checked": today, "status": "error", "error": str(e)[:200]}
        with concurrent.futures.ThreadPoolExecutor(6) as pool:
            recs = list(pool.map(work, todo))
        save_checks(rd, part, recs)
        counts = {}
        for r in recs:
            counts[r["status"]] = counts.get(r["status"], 0) + 1
        print(f"{part}: {json.dumps(counts)}")

def cmd_record(a):
    rd, today = run_dir(a.run), datetime.date.today().isoformat()
    s = next((s for s in sources() if s["id"] == a.source), None) or sys.exit(f"unknown source {a.source}")
    if part_of(s) != a.part:
        sys.exit(f"{a.source} belongs to part {part_of(s)}, not {a.part}")
    rec = check(s, Path(a.file).read_text(), rd, a.part, today)
    save_checks(rd, a.part, [rec])
    print(json.dumps({k: v for k, v in rec.items() if k != "posts"}))

def cmd_status(a):
    rd = run_dir(a.run)
    want = {}
    for s in sources():
        if s["active"]:
            want.setdefault(part_of(s), set()).add(s["id"])
    for part, ids in sorted(want.items()):
        done = {r["id"]: r["status"] for r in read_json(rd / "gyms" / part / "checks.json", [])}
        props = len(read_json(rd / "gyms" / part / "proposals.json", []))
        counts = {}
        for st in done.values():
            counts[st] = counts.get(st, 0) + 1
        state = "DONE" if (rd / "gyms" / part / "done.json").exists() else "open"
        print(f"{part}\t{state}\t{len(ids & done.keys())}/{len(ids)} checked\t{json.dumps(counts)}\tproposals {props}")

def cmd_done(a):
    """Mark a part finished: every source checked, proposals and notes written. Ready for review."""
    rd = run_dir(a.run)
    folder = rd / "gyms" / a.part
    if not folder.exists():
        sys.exit(f"unknown part {a.part}")
    if not (folder / "notes.md").exists():
        sys.exit(f"write {folder / 'notes.md'} first (see docs/weekly-refresh.md, step 5)")
    want = {s["id"] for s in sources() if s["active"] and part_of(s) == a.part}
    done = {r["id"] for r in read_json(folder / "checks.json", [])}
    missing = sorted(want - done)
    write_json(folder / "done.json", {"at": datetime.datetime.now().isoformat(timespec="minutes"),
                                      "unchecked": missing})
    print(f"{a.part} done; unchecked: {len(missing)}" + (f" ({', '.join(missing)})" if missing else ""))

def cmd_merge(a):
    """Last week's list + every part's checks and source changes -> the new sources.json.
    Every part's proposals -> the run's proposals.json, refs prefixed with the part.
    Then a duplicate check of each new proposal against the catalogue and the other proposals."""
    rd = run_dir(a.run)
    new = {s["id"]: dict(s) for s in sources()}
    notes, proposals = [], []
    for part_dir in sorted((rd / "gyms").iterdir()):
        part = part_dir.name
        for r in read_json(part_dir / "checks.json", []):
            s = new.get(r["id"])
            if not s or r["status"] == "error":
                if s:
                    s["last_error"] = r.get("error")
                continue
            s["last_checked"], s["fingerprint"] = r["checked"], r["fingerprint"]
            s.pop("last_error", None)
            if r.get("copy"):
                s["last_copy"] = r["copy"]
            if r.get("posts"):
                s["seen_posts"] = sorted(set(s.get("seen_posts", [])) | set(r["posts"]))
        changes = read_json(part_dir / "source-changes.json", {})
        for entry in changes.get("add", []):
            if entry["id"] in new:
                notes.append(f"{part}: source id {entry['id']} already exists, not added")
                continue
            new[entry["id"]] = {"fingerprint": None, "last_copy": None, "last_checked": None, "active": True,
                                "origin": f"found {rd.name}", **entry}
        for u in changes.get("update", []):
            if u["id"] in new:
                new[u["id"]].update({k: v for k, v in u.items() if k != "id"})
                new[u["id"]]["fingerprint"] = None  # a moved page starts fresh
        for d in changes.get("deactivate", []):
            if d["id"] in new:
                new[d["id"]].update(active=False, note=d.get("note"))
        for p in read_json(part_dir / "proposals.json", []):
            p = dict(p, part=part, ref=f"{part}/{p['ref']}" if not p["ref"].startswith(part + "/") else p["ref"])
            proposals.append(p)
    write_json(SOURCES, sorted(new.values(), key=lambda s: s["id"]))
    write_json(rd / "proposals.json", proposals)

    from catalogue import open_db, listings, similar
    db = HERE.parent / "climb_ontario_dev.db"
    rows = listings(open_db(db))
    venues = {l["gym"]: l["venue_id"] for l in rows}
    def probe(p):
        at = p.get("attrs", {})
        dates = [x["date"] for x in p.get("sessions") or []]
        return {"venue_id": venues.get(p.get("gym")), "title": at.get("title", ""), "dates": dates,
                "start_date": at.get("start_date"), "end_date": at.get("end_date") or at.get("start_date")}
    dupes = []
    news = [p for p in proposals if p.get("action") == "new"]
    for i, p in enumerate(news):
        for l in rows:
            if (s := similar(probe(p), l)):
                dupes.append(f"{p['ref']} may duplicate listing {l['id']} ({l['title']}), score {s}")
        for q in news[i + 1:]:
            if (s := similar(probe(p), probe(q))):
                dupes.append(f"{p['ref']} and {q['ref']} may be the same event, score {s}")
    write_json(rd / "duplicates.json", dupes)
    print(f"sources: {len(new)} ({sum(1 for s in new.values() if s['active'])} active); proposals: {len(proposals)}; "
          f"possible duplicates: {len(dupes)}")
    for n in notes + dupes:
        print("  " + n)

def cmd_dev(a):
    snap = sorted((DATA / "snapshots").glob("catalogue-*.sqlite"))[-1]
    dev = HERE.parent / "climb_ontario_dev.db"
    for leftover in (dev.with_name(dev.name + "-wal"), dev.with_name(dev.name + "-shm")):
        leftover.unlink(missing_ok=True)  # a stale write-ahead log would replay old rows over the copy
    dev.write_bytes(snap.read_bytes())
    print(f"{dev.name} <- {snap.name}")

ap = argparse.ArgumentParser()
ap.add_argument("--run")
sub = ap.add_subparsers(dest="cmd", required=True)
p = sub.add_parser("start"); p.add_argument("date", nargs="?"); p.set_defaults(f=cmd_start)
p = sub.add_parser("parts"); p.set_defaults(f=cmd_parts)
p = sub.add_parser("fetch"); p.add_argument("parts", nargs="+"); p.set_defaults(f=cmd_fetch)
p = sub.add_parser("record"); p.add_argument("part"); p.add_argument("source"); p.add_argument("file"); p.set_defaults(f=cmd_record)
p = sub.add_parser("status"); p.set_defaults(f=cmd_status)
p = sub.add_parser("done"); p.add_argument("part"); p.set_defaults(f=cmd_done)
p = sub.add_parser("merge"); p.set_defaults(f=cmd_merge)
p = sub.add_parser("dev"); p.set_defaults(f=cmd_dev)
a = ap.parse_args(); a.f(a)
