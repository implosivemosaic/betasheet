#!/usr/bin/env python3
"""Rock Gym Pro booking pages draw their calendar with a script, so their visible text has no
dates. The page does embed them as `dates_data`: every bookable date with its start time. This
reads it from this box, no browser needed.

  research/rgp.py URL_OR_CODE [...]   print each offering's title, description and dates

End times aren't in `dates_data`; open the page in agent-browser for those. "unavailable" means
not bookable yet or closed, not cancelled: it is still a scheduled session.
"""
import html, json, re, sys, urllib.request

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0 Safari/537.36"

def dates(raw):
    """[(date, [start datetimes], sold_out, available)] from a page's dates_data, sorted."""
    m = re.search(r"dates_data\s*=\s*(\{.*?\})\s*;", raw, re.S)
    if not m:
        return []
    try:
        data = json.loads(m.group(1))
    except ValueError:
        return []
    return [(d, v.get("specific_datetimes") or [], bool(v.get("sold_out")), bool(v.get("is_available")))
            for d, v in sorted(data.items())]

def date_lines(raw):
    """Calendar as plain lines, appended to a page's readable text so its fingerprint changes
    when dates do."""
    out = []
    for d, starts, sold, avail in dates(raw):
        times = ", ".join(s[11:16] for s in starts) or "time not shown"
        out.append(f"{d} {times}" + (" full" if sold else "") + ("" if avail else " unavailable"))
    return out

def url_for(arg):
    return arg if "://" in arg else f"https://app.rockgympro.com/b/?bo={arg}"

if __name__ == "__main__":
    for arg in sys.argv[1:]:
        u = url_for(arg)
        raw = urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA}), timeout=25).read().decode("utf-8", "replace")
        text = re.sub(r"(?is)<(script|style).*?</\1>", " ", raw)
        text = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", text))).strip()
        start = text.find("Change")
        body = text[start + 6:] if start != -1 else text
        body = body.split("Select Date, Time, and Participants")[0].strip()
        print(f"## {u}\n{body[:1500]}\n")
        lines = date_lines(raw)
        print("\n".join(lines) if lines else "(no dates_data: no bookable dates, or a list page)")
        print()
