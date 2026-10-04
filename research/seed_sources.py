#!/usr/bin/env python3
"""One-off: build betasheet-data/betasheet/sources.json from the September research
database's channel table plus the URLs published listings cite. Run once, 2026-10-04.

Usage: research/seed_sources.py RESEARCH_DB CATALOGUE_DB OUT_JSON
"""
import json, re, sqlite3, sys
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

research_db, catalogue_db, out = sys.argv[1:4]

def norm(url):
    """Comparable form of a URL: https, lower-case host without www, no fragment, sorted query."""
    p = urlsplit(url.strip())
    host = p.netloc.lower().removeprefix("www.")
    path = p.path or "/"
    if path != "/" and path.endswith("/") and "rockgympro" not in host:
        path = path.rstrip("/")
    query = urlencode(sorted((k, v) for k, v in parse_qsl(p.query) if k not in ("random", "iframeid")))
    return urlunsplit(("https", host, path, query, ""))

def kind(url, platform=None):
    h = urlsplit(url).netloc.lower()
    if "climbontario.ca" in h: return "ocf"
    if "instagram.com" in h: return "instagram"
    if "facebook.com" in h: return "facebook"
    if platform in ("booking", "registration") or any(s in h for s in ("rockgympro", "rphq.com", "portal.", "sendmoregetbeta", "eventbrite", "2mev")):
        return "booking page"
    return "web page"

def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:40]

rc = sqlite3.connect(research_db)
cc = sqlite3.connect(catalogue_db)
venues = {gid: name for gid, name in cc.execute("select source_gym_id, name from venues")}
last = dict(rc.execute("select channel_id, max(checked_at) from event_source_checks group by channel_id"))

sources = {}
def add(url, gym_id, platform, checked, origin):
    k = kind(url, platform)
    if k == "instagram" and re.search(r"/(p|reel|stories)/", url):
        return  # a single post is evidence, not a place to watch
    key = norm(url)
    s = sources.setdefault(key, {"url": url, "type": k, "fetch": "browser" if k in ("instagram", "facebook") else "box",
                                 "gyms": [], "last_checked": None, "fingerprint": None, "last_copy": None,
                                 "active": True, "origin": origin})
    name = venues.get(gym_id)
    if name and name not in s["gyms"]:
        s["gyms"].append(name)
    if checked and (s["last_checked"] or "") < checked[:10]:
        s["last_checked"] = checked[:10]

for cid, gym_id, url, platform in rc.execute("select id, gym_id, url, platform from event_channels"):
    add(url, gym_id, platform, last.get(cid), "research channel")

for link, srcs, checked, gym_id in cc.execute(
        "select l.link, l.sources, l.checked_on, v.source_gym_id from listings l join venues v on v.id = l.venue_id where l.published = 1"):
    for url in {link, *json.loads(srcs or "[]")} - {None, ""}:
        add(url, gym_id, None, checked, "listing source")

used = set()
rows = []
for s in sorted(sources.values(), key=lambda s: (s["gyms"][:1], s["type"], s["url"])):
    base = slug((s["gyms"][0] if len(s["gyms"]) == 1 else "shared") + "-" + s["type"])
    sid, n = base, 2
    while sid in used:
        sid, n = f"{base}-{n}", n + 1
    used.add(sid)
    rows.append({"id": sid, **s})

with open(out, "w") as f:
    json.dump(rows, f, ensure_ascii=False, indent=1)
    f.write("\n")
