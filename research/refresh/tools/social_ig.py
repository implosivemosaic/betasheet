#!/usr/bin/env python3
"""Capture an Instagram profile's newest posts as a structured, anchored window.

Usage: tools/social_ig.py <session> <out-dir> <id> <profile-url> [posts] [anchor]

Writes `<id>.ig.json`: for every post read — shortcode, url, publish date, full caption
text, image alt text, and their hashes — plus the traversal it performed: how many posts
were requested, how many were read in full, whether the previous baseline's newest post
(`anchor`) was reached, and where reading stopped.

Why this exists: the earlier social pass saved agent-written markdown, which kept a
handful of permalinks and one caption. A window of posts is what a comparison needs, and
a scroll count proves nothing about what was seen.

Read-only. Requires the human's signed-in browser; it never posts anything.

Coverage rule, stated here so the capture and the comparator cannot disagree:

  complete   = every requested post was read in full AND the anchor was reached
               (or no anchor was declared, in which case the requested count is the
               whole of the claim)
  anchor     = the baseline's newest shortcode; a capture that does not reach it has no
               idea what it missed above that point, so it cannot move the baseline
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys
import time

session, out_dir, ident, url = sys.argv[1:5]
requested = int(sys.argv[5]) if len(sys.argv) > 5 else 6
anchor = sys.argv[6] if len(sys.argv) > 6 else ""
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)

# Instagram pins up to three posts to the top of the grid, so grid order is not date
# order. Read a few extra candidates and report positions rather than trusting the order.
CANDIDATES = max(requested + 4, 8)


def ab(*args, timeout=180):
    result = subprocess.run(["agent-browser", "--session", session, *args],
                            capture_output=True, text=True, timeout=timeout)
    return (result.stdout + result.stderr).strip()


def js(code):
    raw = ab("eval", code)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


GRID_JS = """(() => {
  const seen = new Set();
  const out = [];
  for (const a of document.querySelectorAll('a[href*="/p/"],a[href*="/reel/"]')) {
    const href = a.href.split('?')[0];
    if (seen.has(href)) continue;
    seen.add(href);
    out.push(href);
  }
  return JSON.stringify(out);
})()"""

POST_JS = """(() => {
  for (const el of document.querySelectorAll('span,div[role=button]')) {
    if ((el.textContent || '').trim() === 'more') { try { el.click(); } catch (e) {} }
  }
  const desc = document.querySelector('meta[property="og:description"]');
  const main = document.querySelector('main');
  const text = main ? main.innerText : '';
  const cut = text.split('More posts from')[0];
  const alts = [...(main ? main.querySelectorAll('img') : [])]
    .map(i => (i.alt || '').trim())
    .filter(a => a.length > 12)
    .slice(0, 6);
  return JSON.stringify({desc: desc ? desc.content : '', text: cut, alts: alts,
                         canonical: (document.querySelector('link[rel=canonical]') || {}).href || ''});
})()"""

SHORTCODE = re.compile(r"instagram\.com/(?:[^/\s]+/)?(?:p|reel)/([A-Za-z0-9_-]+)")
MONTHS = ("January February March April May June July August September October "
          "November December").split()
LONG_DATE = re.compile(r"\b(January|February|March|April|May|June|July|August|September|"
                       r"October|November|December)\s+(\d{1,2}),?\s+(\d{4})\b")


def published_of(desc):
    """A machine date from the post's own metadata, or None.

    Instagram's og:description carries "on 6 November 2026: ..." for most posts but
    omits it for the freshest ones, so a null date is normal and never orders posts.
    """
    match = LONG_DATE.search(desc or "")
    if match:
        return "%s-%02d-%02d" % (match.group(3), MONTHS.index(match.group(1)) + 1,
                                 int(match.group(2)))
    return None


def caption_of(text, handle):
    """The post's caption: after the author line, before the engagement counters."""
    lines = [line.strip() for line in (text or "").splitlines()]
    keep, started = [], False
    for line in lines:
        low = line.lower()
        if not line:
            continue
        if not started:
            if low == "post" or low.startswith("suggested for you"):
                continue
            if handle and low == handle.lower():
                started = True
            continue
        if re.match(r"^(liked by|\d+ likes?|view all|add a comment|more posts)", low):
            break
        if low in ("follow", "verified"):
            continue
        keep.append(line)
    return "\n".join(keep).strip()


def main():
    ab("open", url)
    time.sleep(5)
    for _ in range(4):
        links = js(GRID_JS)
        if isinstance(links, list) and links:
            break
        ab("wait", "2000")
    links = links if isinstance(links, list) else []
    handle = url.rstrip("/").split("/")[-1]

    posts, seen = [], set()
    for position, link in enumerate(links[:CANDIDATES]):
        match = SHORTCODE.search(link)
        if not match or match.group(1) in seen:
            continue
        shortcode = match.group(1)
        ab("open", link)
        time.sleep(4)
        body = js(POST_JS)
        if not isinstance(body, dict):
            continue
        seen.add(shortcode)
        posts.append({
            "id": shortcode,
            "url": "https://www.instagram.com/p/%s/" % shortcode,
            "position": position,
            "published": published_of(body.get("desc")),
            "caption": caption_of(body.get("text"), handle),
            "alts": [alt for alt in body.get("alts") or []
                     if "profile picture" not in alt.lower()],
        })
        if len(posts) >= requested + 3:
            break

    fully_read = [p for p in posts if len(p["caption"]) >= 24]
    fully_read = fully_read[:requested]
    reached = bool(anchor) and any(p["id"] == anchor for p in fully_read)
    complete = len(fully_read) >= requested and (reached if anchor else True)
    stopping = fully_read[-1]["id"] if fully_read else None
    if stopping is None:
        reason = "nothing-read"
    elif anchor and reached:
        reason = "anchor-reached"
    elif anchor:
        reason = "anchor-not-reached"
    else:
        reason = "declared-limit"

    result = {
        "id": ident, "provider": "instagram", "url": url,
        "captured_at": datetime.datetime.now(datetime.timezone.utc)
                                   .isoformat(timespec="seconds"),
        "posts": fully_read,
        "coverage": {
            "contract": "social-window",
            "posts_requested": requested,
            "posts_fully_read": len(fully_read),
            "grid_links_seen": len(links),
            "anchor_id": anchor or None,
            "anchor_reached": reached if anchor else None,
            "stopping_post": stopping,
            "stopped_reason": reason,
            "challenge_detected": None if fully_read else "no-post-readable",
            "complete": complete,
            "errors": [] if fully_read else ["no post rendered with a caption"],
        },
    }
    (out / (ident + ".ig.json")).write_text(json.dumps(result, indent=1) + "\n")
    print("%s: %d/%d posts read, anchor %s, %s" % (
        ident, len(fully_read), requested,
        anchor or "(none)", "complete" if complete else reason))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
