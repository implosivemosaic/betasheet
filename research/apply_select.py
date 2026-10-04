"""Approved proposals this target hasn't applied yet, as JSON on stdout. Used by apply.sh."""
import json, sys
run, target = sys.argv[1], sys.argv[2]
done = {r["ref"] for r in json.load(open(f"{run}/applied.json")) if r["target"] == target and r["status"] == "ok"}
print(json.dumps([e for e in json.load(open(f"{run}/proposals.json")) if e.get("approved") is True and e.get("ref") not in done]))
