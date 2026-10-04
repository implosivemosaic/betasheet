"""Append apply results to applied.json and give new listings their assigned ID in
proposals.json, so the next target (prod after dev) uses the same ID. Used by apply.sh."""
import json, sys
run, target, lines = sys.argv[1:4]
new = [dict(json.loads(l), target=target) for l in open(lines) if l.strip()]
applied = json.load(open(f"{run}/applied.json"))
json.dump(applied + new, open(f"{run}/applied.json", "w"), ensure_ascii=False, indent=1)
props = json.load(open(f"{run}/proposals.json"))
ids = {r["ref"]: r["id"] for r in new if r["status"] == "ok"}
for e in props:
    if e.get("action") == "new" and e.get("ref") in ids:
        e["id"] = ids[e["ref"]]
json.dump(props, open(f"{run}/proposals.json", "w"), ensure_ascii=False, indent=1)
for r in new:
    print(r["status"], r["id"], r.get("title") or r.get("error"))
