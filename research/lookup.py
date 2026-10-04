#!/usr/bin/env python3
"""Which listings already cite this link or ID?

Usage: research/lookup.py CATALOGUE_DB URL_OR_ID
  URL_OR_ID: a full URL, an ID such as rgp:0779703bfa7240b5b4b9bdb94bd00cf5 or ig:DZLybHfJQr3,
  or a bare booking code. Prints matching listings, or nothing.
"""
import sys
from catalogue import open_db, find

db, query = sys.argv[1], sys.argv[2]
for l, why in find(open_db(db), query):
    state = "published" if l["published"] else "draft"
    print(f"{l['id']}\t{state}\t{why}\t{l['gym']}\t{l['title']}\t{l['start_date']}..{l['end_date']}")
