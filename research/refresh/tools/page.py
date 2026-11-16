#!/usr/bin/env python3
"""Capture one web page as durable evidence, and say what kind of document it is.

Usage: tools/page.py <session> <out-dir> <id> <url>

Writes `<id>.txt`, `<id>.html`, `<id>.links.txt`, `<id>.norm.txt` and `<id>.meta.json`
with a coverage block that records the shell or notice found, if any. Read-only.

The classification is the one the comparator uses (`extract.page_signature`), so a
capture and its later comparison cannot disagree about whether a page was read: a
Cloudflare challenge, a JavaScript-only shell, a soft 404 inside site chrome and a
"this plan is inactive" notice are all recorded here, at capture time, when the
evidence is in hand.
"""
import datetime
import hashlib
import json
import pathlib
import subprocess
import sys

import coverage
from extract import page_signature

session, out_dir, ident, url = sys.argv[1:5]
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)


def ab(*args):
    result = subprocess.run(["agent-browser", "--session", session, *args],
                            capture_output=True, text=True, timeout=180)
    return result.stdout.strip()


def js(expr):
    raw = ab("eval", expr)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


ab("open", url)
# Chrome renders asynchronously: poll the DOM until the page has real text.
for _ in range(8):
    length = js("document.body ? document.body.innerText.length : 0")
    if isinstance(length, int) and length > 80:
        break
    ab("wait", "2000")

text = ab("get", "text", "body")
(out / (ident + ".txt")).write_text(text)
html = js("document.documentElement.outerHTML")
(out / (ident + ".html")).write_text(html if isinstance(html, str) else json.dumps(html))
links = js('Array.from(document.querySelectorAll("a[href]"))'
           '.map(a => a.href + "\\t" + (a.innerText || "").trim().replace(/\\s+/g, " ")).join("\\n")')
(out / (ident + ".links.txt")).write_text(links if isinstance(links, str) else "")

norm = "\n".join(line.strip() for line in text.splitlines() if line.strip())
(out / (ident + ".norm.txt")).write_text(norm)
lines = len([line for line in norm.splitlines() if line.strip()])
kind, signature = page_signature(norm)

meta = {
    "id": ident, "requested_url": url,
    "final_url": js("location.href") or url,
    "title": js("document.title") or "",
    "captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds"),
    "text_sha256": hashlib.sha256(" ".join(norm.split()).encode()).hexdigest(),
    "text_lines": lines,
    "coverage": coverage.page(
        lines,
        challenge=signature if kind == "unreadable" else None,
        notice=signature if kind == "notice" else None,
    ),
}
(out / (ident + ".meta.json")).write_text(json.dumps(meta, indent=1) + "\n")
print("%s: %d lines, %s" % (ident, lines, "%s (%s)" % (kind, signature) if kind else "page"))
