#!/usr/bin/env python3
"""Possible duplicates: same gym, alike names (season words ignored), overlapping dates.

Usage:
  research/similar.py CATALOGUE_DB --all
      every pair of existing listings that look like the same event
  research/similar.py CATALOGUE_DB --gym "Junction Climbing Centre" --title "Junior Crushers" --from 2026-09-18 --to 2026-12-03
      existing listings a proposed new listing may duplicate
"""
import argparse
from catalogue import open_db, listings, similar

ap = argparse.ArgumentParser()
ap.add_argument("db")
ap.add_argument("--all", action="store_true")
ap.add_argument("--gym"); ap.add_argument("--title")
ap.add_argument("--from", dest="start"); ap.add_argument("--to", dest="end")
ap.add_argument("--threshold", type=float, default=0.75)
a = ap.parse_args()
rows = listings(open_db(a.db))

if a.all:
    by_gym = {}
    for l in rows:
        by_gym.setdefault(l["venue_id"], []).append(l)
    for group in by_gym.values():
        for i, x in enumerate(group):
            for y in group[i + 1:]:
                s = similar(x, y, a.threshold)
                if s:
                    print(f"{s}\t{x['id']}\t{y['id']}\t{x['gym']}\t{x['title']}\t|\t{y['title']}")
else:
    venue = next((l["venue_id"] for l in rows if l["gym"] == a.gym), None)
    if venue is None:
        raise SystemExit(f"unknown gym: {a.gym}")
    probe = {"venue_id": venue, "title": a.title, "dates": [], "start_date": a.start, "end_date": a.end or a.start}
    for l in rows:
        s = similar(probe, l, a.threshold)
        if s:
            print(f"{s}\t{l['id']}\t{l['title']}\t{l['start_date']}..{l['end_date']}")
