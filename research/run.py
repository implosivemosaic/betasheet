#!/usr/bin/env python3
"""Bookkeeping for the weekly refresh; the research itself is the researcher's job.
See docs/weekly-refresh.md.

Work is split into parts: one per gym, plus "shared" (the OCF and other multi-gym sources).
Each part writes only into runs/<date>/gyms/<part>/. `merge` gathers every part into the run.

  research/run.py start [DATE]   create runs/DATE/ and a folder per part
  research/run.py parts          list the parts and the gym each one covers
  research/run.py status         which parts are done, with proposal and page counts
  research/run.py done PART      mark a part finished and ready for Keith's review
  research/run.py merge          useful pages -> sources.json; proposals -> the run; duplicate check
  research/run.py dev            local dev database = newest production snapshot

DATA defaults to ../betasheet-data/betasheet next to this repo; the run is the newest folder unless
--run DATE is given.
"""
import argparse, datetime, json, os, re, sqlite3, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
DATA = Path(os.environ.get("DATA", HERE.parents[1] / "betasheet-data" / "betasheet"))
SOURCES = DATA / "sources.json"

def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")

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

def gyms():
    """Gym names from the local catalogue (the dev database)."""
    c = sqlite3.connect(HERE.parent / "climb_ontario_dev.db")
    return sorted(n for (n,) in c.execute("select name from venues"))

def parts():
    return {slug(g): g for g in gyms()} | {"shared": "OCF and sources several gyms share"}

def cmd_start(a):
    name = a.date or datetime.date.today().isoformat()
    rd = run_dir(name)
    for part in parts():
        for f in ("proposals.json", "pages.json"):
            if not (rd / "gyms" / part / f).exists():
                write_json(rd / "gyms" / part / f, [])
    for f in ("proposals.json", "applied.json"):
        if not (rd / f).exists():
            write_json(rd / f, [])
    print(rd)

def cmd_parts(a):
    for part, gym in parts().items():
        print(f"{part}\t{gym}")

def cmd_status(a):
    rd = run_dir(a.run)
    for part in parts():
        d = rd / "gyms" / part
        state = "DONE" if (d / "done.json").exists() else "open"
        print(f"{part}\t{state}\tproposals {len(read_json(d / 'proposals.json', []))}"
              f"\tuseful pages {len(read_json(d / 'pages.json', []))}")

def cmd_done(a):
    """Mark a part finished: proposals, pages and notes written. Ready for Keith's review."""
    folder = run_dir(a.run) / "gyms" / a.part
    if not folder.exists():
        sys.exit(f"unknown part {a.part}")
    if not (folder / "notes.md").exists():
        sys.exit(f"write {folder / 'notes.md'} first (docs/weekly-refresh.md)")
    write_json(folder / "done.json", {"at": datetime.datetime.now().isoformat(timespec="minutes")})
    print(f"{a.part} done")

def cmd_merge(a):
    """Every part's useful pages -> sources.json (new ones added, known ones marked useful this run).
    Every part's proposals -> the run's proposals.json, refs prefixed with the part.
    Then a duplicate check of each new proposal against the catalogue and the other proposals."""
    from catalogue import norm_url, open_db, listings, similar
    rd = run_dir(a.run)
    srcs = sources()
    by_url = {norm_url(s["url"]): s for s in srcs}
    names = parts()
    proposals, added = [], 0
    for part_dir in sorted((rd / "gyms").iterdir()):
        part = part_dir.name
        for pg in read_json(part_dir / "pages.json", []):
            s = by_url.get(norm_url(pg["url"]))
            if s is None:
                gym = pg.get("gym") or names.get(part)
                sid, n = slug(f"{gym}-{pg.get('type', 'page')}"), 2
                while any(x["id"] == sid for x in srcs):
                    sid, n = slug(f"{gym}-{pg.get('type', 'page')}") + f"-{n}", n + 1
                s = {"id": sid, "url": pg["url"], "type": pg.get("type", "web page"),
                     "gyms": [gym] if part != "shared" else pg.get("gyms", []),
                     "active": True, "origin": f"found {rd.name}"}
                srcs.append(s); by_url[norm_url(pg["url"])] = s; added += 1
            s["last_useful"] = rd.name
            s["useful_for"] = pg.get("what")
        for p in read_json(part_dir / "proposals.json", []):
            ref = p["ref"] if p["ref"].startswith(part + "/") else f"{part}/{p['ref']}"
            proposals.append(dict(p, part=part, ref=ref))
    write_json(SOURCES, sorted(srcs, key=lambda s: s["id"]))
    write_json(rd / "proposals.json", proposals)

    rows = listings(open_db(HERE.parent / "climb_ontario_dev.db"))
    venues = {l["gym"]: l["venue_id"] for l in rows}
    def probe(p):
        at = p.get("attrs", {})
        return {"venue_id": venues.get(p.get("gym")), "title": at.get("title", ""),
                "dates": [x["date"] for x in p.get("sessions") or []],
                "start_date": at.get("start_date"), "end_date": at.get("end_date") or at.get("start_date")}
    dupes = []
    news = [p for p in proposals if p.get("action") == "new"]
    for i, p in enumerate(news):
        for l in rows:
            if (sc := similar(probe(p), l)):
                dupes.append(f"{p['ref']} may duplicate listing {l['id']} ({l['title']}), score {sc}")
        for q in news[i + 1:]:
            if (sc := similar(probe(p), probe(q))):
                dupes.append(f"{p['ref']} and {q['ref']} may be the same event, score {sc}")
    write_json(rd / "duplicates.json", dupes)
    print(f"sources: {len(srcs)} ({added} added this run); proposals: {len(proposals)}; possible duplicates: {len(dupes)}")
    for d in dupes:
        print("  " + d)

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
p = sub.add_parser("status"); p.set_defaults(f=cmd_status)
p = sub.add_parser("done"); p.add_argument("part"); p.set_defaults(f=cmd_done)
p = sub.add_parser("merge"); p.set_defaults(f=cmd_merge)
p = sub.add_parser("dev"); p.set_defaults(f=cmd_dev)
a = ap.parse_args(); a.f(a)
