#!/usr/bin/env python3
"""Capture a Facebook page feed as a structured, anchored window.

Usage: tools/social_fb.py <session> <out-dir> <id> <page-url> [steps] [anchor]

Writes `<id>.fb.json`: for every post rendered — the post's own `pcb` / `story_fbid` id,
the ids of its photos (`fbid`), the post text, the image alt text, and their hashes —
plus the traversal performed: how many scroll steps were asked for and run, whether the
previous baseline's newest post (`anchor`) was reached, and where reading stopped.

The ids matter more than the text. A feed walk is inherently partial: it reads what the
scroll loaded. Without ids the previous pass could only hash post bodies, which cannot
tell an edit from a new post, so Facebook sat out every comparison. `pcb` and `fbid`
are different objects — a post and one of its photos — and are kept apart.

Read-only. Requires the human's signed-in browser; it never posts anything.

Coverage rule, matching `social_ig.py` and the comparator:

  complete  = the capture reached the baseline's newest post, or, with no baseline yet,
              ran the declared number of scroll steps and read the declared minimum
"""
import datetime
import json
import pathlib
import re
import subprocess
import sys
import time

session, out_dir, ident, url = sys.argv[1:5]
steps = int(sys.argv[5]) if len(sys.argv) > 5 else 6
anchor = sys.argv[6] if len(sys.argv) > 6 else ""
out = pathlib.Path(out_dir)
out.mkdir(parents=True, exist_ok=True)
MINIMUM = 5

POSTS_JS = r"""(() => {
  for (const b of document.querySelectorAll('[role=button], span, div[role=link]')) {
    if ((b.innerText || '').trim() === 'See more') { try { b.click(); } catch (e) {} }
  }
  const out = [];
  for (const btn of document.querySelectorAll('[aria-label^="Actions for this post"]')) {
    let node = btn;
    for (let i = 0; i < 14 && node; i++) {
      const inner = node.querySelectorAll('[aria-label^="Actions for this post"]').length;
      if (inner <= 1 && node.querySelectorAll('div[dir=auto]').length >= 2) break;
      node = node.parentElement;
    }
    if (!node) continue;
    const postIds = new Set(), photoIds = new Set();
    for (const a of node.querySelectorAll('a[href]')) {
      const href = a.href;
      let m = href.match(/[?&]set=pcb\.(\d{6,})/) || href.match(/[?&]story_fbid=(\d{6,})/);
      if (m) postIds.add(m[1]);
      m = href.match(/[?&]fbid=(\d{6,})/);
      if (m) photoIds.add(m[1]);
    }
    let date = '';
    for (const a of node.querySelectorAll('a[href]')) {
      const t = (a.innerText || '').replace(/\s+/g, ' ').trim();
      if (t.length < 40 && /^[A-Z][a-z]+ \d{1,2}(, \d{4})?( at .*)?$/.test(t)) { date = t; break; }
    }
    const paras = [...node.querySelectorAll('div[dir=auto]')]
      .map(e => (e.innerText || '').trim())
      .filter(s => s.length > 25 && !/^[A-Z][a-z]+ \d{1,2}(, \d{4})?$/.test(s));
    const alts = [...node.querySelectorAll('[aria-label]')]
      .map(e => e.getAttribute('aria-label'))
      .filter(a => a && /(May be an image|May be a graphic|No photo description)/i.test(a));
    out.push({post_ids: [...postIds], photo_ids: [...photoIds], date: date,
              text: [...new Set(paras)].join(' || ').slice(0, 2000),
              alts: [...new Set(alts)].slice(0, 4)});
  }
  return JSON.stringify(out);
})()"""

SCROLL_JS = """(() => {
  window.scrollBy(0, 1050);
  return [window.scrollY, document.body.scrollHeight];
})()"""

MONTHS = ("January February March April May June July August September October "
          "November December").split()
SHORT_DATE = re.compile(r"^([A-Z][a-z]+) (\d{1,2})(?:, (\d{4}))?")
TEXT_KEY = re.compile(r"\W+")
CAPTURED_YEAR = datetime.datetime.now(datetime.timezone.utc).year


def published_of(text):
    """Facebook obfuscates the year on fresh posts; keep the date only when it is real."""
    match = SHORT_DATE.match((text or "").strip())
    if not match or match.group(1) not in MONTHS:
        return None
    year = int(match.group(3) or CAPTURED_YEAR)
    return "%04d-%02d-%02d" % (year, MONTHS.index(match.group(1)) + 1, int(match.group(2)))


def main():
    ab = lambda *args: subprocess.run(
        ["agent-browser", "--session", session, *args],
        capture_output=True, text=True, timeout=240).stdout.strip()

    ab("open", url)
    time.sleep(6)

    posts, order, by_post = [], [], {}
    ran = 0
    for _ in range(steps):
        raw = ab("eval", POSTS_JS)
        try:
            batch = json.loads(raw)
        except json.JSONDecodeError:
            batch = []
        for item in batch:
            key = (item["post_ids"][0] if item["post_ids"]
                   else "text:" + TEXT_KEY.sub(" ", item["text"])[:70])
            if not key or key in by_post:
                continue
            entry = {"post_id": item["post_ids"][0] if item["post_ids"] else None,
                     "photo_ids": item["photo_ids"], "url": None,
                     "published": published_of(item["date"]),
                     "caption": item["text"], "alts": item["alts"]}
            by_post[key] = entry
            order.append(key)
        ran += 1
        if anchor and any((by_post[k].get("post_id") == anchor) for k in order):
            break
        ab("eval", SCROLL_JS)
        time.sleep(3)

    posts = [by_post[k] for k in order]
    identified = [p for p in posts if p["post_id"]]
    reached = bool(anchor) and any(p["post_id"] == anchor for p in identified)
    complete = reached if anchor else (ran >= steps and len(identified) >= MINIMUM)
    stopping = identified[-1]["post_id"] if identified else None
    if not posts:
        reason = "nothing-read"
    elif anchor and reached:
        reason = "anchor-reached"
    elif anchor:
        reason = "anchor-not-reached"
    elif complete:
        reason = "declared-limit"
    else:
        reason = "short-of-minimum"

    result = {
        "id": ident, "provider": "facebook", "url": url,
        "captured_at": datetime.datetime.now(datetime.timezone.utc)
                                   .isoformat(timespec="seconds"),
        "posts": posts,
        "coverage": {
            "contract": "social-window",
            "posts_requested": None,
            "steps_requested": steps,
            "steps_run": ran,
            "posts_read": len(posts),
            "posts_with_ids": len(identified),
            "minimum": MINIMUM,
            "anchor_id": anchor or None,
            "anchor_reached": reached if anchor else None,
            "stopping_post": stopping,
            "stopped_reason": reason,
            "challenge_detected": None if posts else "no-post-rendered",
            "complete": complete,
            "errors": [] if posts else ["no post rendered"],
        },
    }
    (out / (ident + ".fb.json")).write_text(json.dumps(result, indent=1) + "\n")
    print("%s: %d posts (%d with ids), %d/%d steps, anchor %s, %s" % (
        ident, len(posts), len(identified), ran, steps, anchor or "(none)",
        "complete" if complete else reason))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
