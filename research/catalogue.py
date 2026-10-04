"""Shared helpers for the research tools: read a Beta Sheet catalogue SQLite file
(the dev database or a production snapshot), normalize source links, pull the
IDs that booking systems, Instagram and the OCF put in their URLs, and score how
alike two listings are. Read-only: nothing here writes to a catalogue."""
import difflib, json, re, sqlite3
from datetime import date
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode

def norm_url(url):
    """Comparable form of a URL: https, lower-case host without www, no fragment,
    no tracking parameters, sorted query."""
    p = urlsplit(url.strip())
    host = p.netloc.lower().removeprefix("www.")
    path = p.path or "/"
    if path != "/" and path.endswith("/") and "rockgympro" not in host:
        path = path.rstrip("/")
    drop = {"random", "iframeid", "fbclid", "igsh", "utm_source", "utm_medium", "utm_campaign"}
    query = urlencode(sorted((k, v) for k, v in parse_qsl(p.query) if k not in drop))
    return urlunsplit(("https", host, path, query, ""))

KEY_PATTERNS = [
    ("rgp", r"[?&](?:bo|offering_guid)=([0-9a-f]{32})"),
    ("ig", r"instagram\.com/(?:p|reel)/([\w-]+)"),
    ("ocf", r"climbontario\.ca/events/([\w-]+)"),
    ("eventbrite", r"eventbrite\.\w+/e/(?:[\w-]*-)?(\d{9,})"),
    ("redpoint", r"((?:portal\.[\w.-]+|[\w-]+\.rphq\.com)/[\w-]+/programs/[\w-]+)"),
]

def keys(url):
    """IDs a source system put in this URL, e.g. ['rgp:0779703b…']."""
    out = []
    for name, pat in KEY_PATTERNS:
        m = re.search(pat, url)
        if m:
            out.append(f"{name}:{m.group(1).lower()}")
    return out

def open_db(path):
    c = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    c.row_factory = sqlite3.Row
    return c

def listings(c, published_only=False):
    q = """select l.*, v.name as gym from listings l join venues v on v.id = l.venue_id"""
    if published_only:
        q += " where l.published = 1"
    rows = []
    for r in c.execute(q):
        l = dict(r)
        l["urls"] = sorted({u for u in [l["link"], *json.loads(l["sources"] or "[]")] if u})
        l["keys"] = sorted({k for u in l["urls"] for k in keys(u)})
        l["dates"] = sorted(d for (d,) in c.execute("select date from occurrences where listing_id = ?", (l["id"],)))
        rows.append(l)
    return rows

def find(c, query):
    """Listings that cite this URL, or carry this ID (a full URL, or 'rgp:…', or a bare code)."""
    q = query.strip()
    want_keys = set(keys(q)) if "://" in q else {q.lower()} if ":" in q else {f"{n}:{q.lower()}" for n, _ in KEY_PATTERNS}
    want_url = norm_url(q) if "://" in q else None
    hits = []
    for l in listings(c):
        by_url = want_url and want_url in {norm_url(u) for u in l["urls"]}
        by_key = want_keys & set(l["keys"])
        if by_url or by_key:
            hits.append((l, "same link" if by_url else "same ID " + ", ".join(sorted(by_key))))
    return hits

SEASON = r"\b(fall|autumn|winter|spring|summer|session|semester|term|20\d\d(?:[–-]20?\d\d)?|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\b"

# Words that make two otherwise alike names different programmes, not the same one.
DISTINCT = {"jr", "junior", "sr", "senior", "beginner", "intermediate", "advanced", "level", "ages",
            "kids", "teen", "teens", "adult", "adults", "youth", "parent", "baby", "prenatal",
            "climber", "climbing", "ninja", "boulder", "boulders", "bouldering", "rope", "lead"}

def title_core(title):
    """The title without season, year and date words, for comparing names across terms."""
    t = re.sub(SEASON, " ", title.lower())
    return re.sub(r"[^a-z0-9]+", " ", t).strip()

def span(l):
    days = [date.fromisoformat(d) for d in l["dates"]]
    if l["start_date"]:
        days.append(date.fromisoformat(l["start_date"]))
    if l["end_date"]:
        days.append(date.fromisoformat(l["end_date"]))
    return (min(days), max(days)) if days else None

def overlaps(a, b):
    sa, sb = span(a), span(b)
    if sa is None or sb is None:
        return sa is None and sb is None  # both undated: can't rule out a duplicate
    return sa[0] <= sb[1] and sb[0] <= sa[1]

def similar(a, b, threshold=0.75):
    """Same gym, alike names (season words ignored) and overlapping dates."""
    if a["venue_id"] != b["venue_id"]:
        return None
    ta, tb = set(title_core(a["title"]).split()), set(title_core(b["title"]).split())
    if any(t.isdigit() or t in DISTINCT or re.search(r"\d", t) for t in ta ^ tb):
        return None  # e.g. Level 1 vs Level 2, Jr vs Sr, 101 vs 201
    score = difflib.SequenceMatcher(None, title_core(a["title"]), title_core(b["title"])).ratio()
    if score >= threshold and overlaps(a, b):
        return round(score, 2)
    return None
