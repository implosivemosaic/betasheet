#!/usr/bin/env python3
"""Mechanical steps of the weekly refresh. Judgment stays with the researcher;
see docs/weekly-refresh.md for the whole run.

  research/run.py start [DATE]           create runs/DATE/ in betasheet-data
  research/run.py fetch [--only IDS]     read every active "box" source, fingerprint it,
                                         save text and a diff for the ones that changed
  research/run.py record SOURCE_ID FILE  same, for a "browser" source whose text you saved
                                         from the human's browser (Instagram, Facebook)
  research/run.py status                 what this run has checked so far
  research/run.py dev                    replace the local dev database with the newest
                                         production snapshot (take one first: bin/pull-prod-db.sh)

DATA defaults to ../betasheet-data next to this repo; RUN defaults to the newest run folder.
"""
import argparse, concurrent.futures, datetime, difflib, hashlib, html, json, os, re, sys, urllib.request
from pathlib import Path

DATA = Path(os.environ.get("DATA", Path(__file__).resolve().parents[2] / "betasheet-data")) / "betasheet"
SOURCES = DATA / "sources.json"
UA = "Mozilla/5.0 (compatible; BetaSheet research; +https://betasheet.ca/about)"

def load():
    return json.loads(SOURCES.read_text())

def save(sources):
    SOURCES.write_text(json.dumps(sources, ensure_ascii=False, indent=1) + "\n")

def run_dir(name=None):
    runs = sorted((DATA / "runs").glob("20*"))
    if name:
        return DATA / "runs" / name
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

def compare(source, text, rd, today):
    """Fingerprint the text; on change save it and a diff against the last copy."""
    fp = hashlib.sha256(text.encode()).hexdigest()[:16]
    result = {"id": source["id"], "url": source["url"], "gyms": source["gyms"], "type": source["type"]}
    if fp == source.get("fingerprint"):
        result["status"] = "unchanged"
    else:
        result["status"] = "new" if not source.get("fingerprint") else "changed"
        rel = f"runs/{rd.name}/pages/{source['id']}.txt"
        prev = DATA / source["last_copy"] if source.get("last_copy") else None
        before = prev.read_text() if prev and prev.exists() else None
        (DATA / rel).write_text(text)
        if before is not None:
            diff = difflib.unified_diff(before.splitlines(), text.splitlines(), "last", "now", lineterm="", n=1)
            (rd / "pages" / f"{source['id']}.diff").write_text("\n".join(diff) + "\n")
        if source["type"] == "instagram":
            seen = set(source.get("seen_posts", []))
            posts = instagram_posts(text)
            result["new_posts"] = [p for p in posts if p not in seen]
            source["seen_posts"] = sorted(seen | set(posts))
        source["fingerprint"], source["last_copy"] = fp, rel
    source["last_checked"] = today
    return result

def fetch_one(source):
    req = urllib.request.Request(source["url"], headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return readable(r.read().decode(r.headers.get_content_charset() or "utf-8", "replace"))

def write_log(rd, results):
    log = rd / "checks.json"
    old = {r["id"]: r for r in json.loads(log.read_text())} if log.exists() else {}
    old.update({r["id"]: r for r in results})
    log.write_text(json.dumps(sorted(old.values(), key=lambda r: r["id"]), ensure_ascii=False, indent=1) + "\n")

def cmd_start(a):
    name = a.date or datetime.date.today().isoformat()
    rd = run_dir(name)
    (rd / "pages").mkdir(parents=True, exist_ok=True)
    report = rd / "report.md"
    if not report.exists():
        report.write_text(f"# Weekly refresh {name}\n\n## Checked\n\n## New\n\n## Changed\n\n## Possible duplicates\n\n## Uncertain or blocked\n\n## Source list changes\n")
    for f in ("proposals.json", "applied.json"):
        if not (rd / f).exists():
            (rd / f).write_text("[]\n")
    print(rd)

def cmd_fetch(a):
    rd, sources, today = run_dir(a.run), load(), datetime.date.today().isoformat()
    todo = [s for s in sources if s["active"] and s["fetch"] == "box" and (not a.only or s["id"] in a.only.split(","))]
    results = []
    def work(s):
        try:
            return compare(s, fetch_one(s), rd, today)
        except Exception as e:
            return {"id": s["id"], "url": s["url"], "gyms": s["gyms"], "type": s["type"], "status": "error", "error": str(e)[:200]}
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        for r in pool.map(work, todo):
            results.append(r)
    save(sources)
    write_log(rd, results)
    counts = {}
    for r in results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    print(json.dumps(counts))

def cmd_record(a):
    rd, sources, today = run_dir(a.run), load(), datetime.date.today().isoformat()
    s = next((s for s in sources if s["id"] == a.source), None) or sys.exit(f"unknown source {a.source}")
    r = compare(s, Path(a.file).read_text(), rd, today)
    save(sources)
    write_log(rd, [r])
    print(json.dumps(r))

def cmd_status(a):
    rd, sources = run_dir(a.run), load()
    log = json.loads((rd / "checks.json").read_text()) if (rd / "checks.json").exists() else []
    done = {r["id"] for r in log}
    counts = {}
    for r in log:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
    waiting = [s["id"] for s in sources if s["active"] and s["id"] not in done]
    print(f"{rd.name}: {json.dumps(counts)}; not yet checked: {len(waiting)} "
          f"({sum(1 for s in sources if s['active'] and s['id'] in waiting and s['fetch'] == 'browser')} need the browser)")

def cmd_dev(a):
    snap = sorted((DATA / "snapshots").glob("catalogue-*.sqlite"))[-1]
    dev = Path(__file__).resolve().parents[1] / "climb_ontario_dev.db"
    for leftover in (dev.with_name(dev.name + "-wal"), dev.with_name(dev.name + "-shm")):
        leftover.unlink(missing_ok=True)  # a stale write-ahead log would replay old rows over the copy
    dev.write_bytes(snap.read_bytes())
    print(f"{dev.name} <- {snap.name}")

ap = argparse.ArgumentParser()
ap.add_argument("--run")
sub = ap.add_subparsers(dest="cmd", required=True)
p = sub.add_parser("start"); p.add_argument("date", nargs="?"); p.set_defaults(f=cmd_start)
p = sub.add_parser("fetch"); p.add_argument("--only"); p.set_defaults(f=cmd_fetch)
p = sub.add_parser("record"); p.add_argument("source"); p.add_argument("file"); p.set_defaults(f=cmd_record)
p = sub.add_parser("status"); p.set_defaults(f=cmd_status)
p = sub.add_parser("dev"); p.set_defaults(f=cmd_dev)
a = ap.parse_args(); a.f(a)
