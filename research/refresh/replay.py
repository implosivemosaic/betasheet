"""Replay a run's saved captures through extract + compare.

A capture compared with itself must never come back `changed`. That sounds trivial and
is the whole point: the November tool called 165 of 562 sources `unchanged` while holding
no comparable content, so "self-comparison is unchanged" is the property the old code
failed in the invisible direction and this one has to hold in both.

    python3 research/refresh/replay.py <evidence-dir> [<evidence-dir> ...]

Prints an outcome table per type, the verdict counts, and every source whose
self-comparison was not `unchanged` or `incomplete`. Exits non-zero if any did.
"""
import collections
import pathlib
import sys

import compare
import extract

CAPTURE_SUFFIXES = (".rgp.json", ".rphq.json", ".meta.json")


def captures(root):
    root = pathlib.Path(root)
    for path in sorted(root.rglob("*")):
        name = path.name
        if name.endswith(CAPTURE_SUFFIXES) or (
                (name.startswith("ig-") or name.startswith("fb-")) and name.endswith(".md")):
            yield path


def main(argv):
    roots = argv[1:] or [
        "/data/workspace/rooms/db1d902e-609d-4153-9ea3-480f722a6189/"
        "betasheet-data/betasheet/runs/2026-11-11-refresh/gyms"]
    outcomes = collections.Counter()
    verdicts = collections.Counter()
    problems = []
    total = 0

    for root in roots:
        for path in captures(root):
            try:
                record = extract.extract(str(path))
            except Exception as exc:  # a capture we cannot even read is a finding
                problems.append((path, "extract failed: %s" % exc))
                continue
            total += 1
            outcomes[(record["type"], record["outcome"])] += 1
            verdict = compare.compare_source(record, record)
            verdicts[verdict["status"]] += 1
            if verdict["status"] not in ("unchanged", "incomplete"):
                problems.append((path, "self-comparison was %s" % verdict["status"]))
            if record.get("notice"):
                outcomes[(record["type"], "notice:" + record["notice"])] += 1

    print("captures: %d from %d root(s)\n" % (total, len(roots)))
    print("%-12s %-20s %s" % ("type", "outcome", "count"))
    for (kind, outcome), count in sorted(outcomes.items()):
        print("%-12s %-20s %d" % (kind, outcome, count))
    print()
    print("self-comparison verdicts:", dict(verdicts))
    if problems:
        print("\nFAILURES")
        for path, why in problems:
            print("  %s\n    %s" % (path, why))
        return 1
    print("\nno source came back `changed` against itself")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
