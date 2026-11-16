#!/usr/bin/env python3
"""The weekly refresh's registry commands. See REGISTRY.md.

    refresh.py capture  <id> --run R --session S --by NAME [--force]
    refresh.py ingest   <id> --run R --by NAME
    refresh.py review   --run R --gym G [--source ID ...] [--all-gyms] --by NAME --note TEXT
    refresh.py status   --run R [--gym G]
    refresh.py close    --run R [--dry-run]
    refresh.py register <url> --gym G [--gym G2] --type T [--id ID]
    refresh.py recover  --from RUN [--out DIR | --apply] [--register-discovered]

`--data` (or $BETASHEET_DATA) is betasheet-data's `betasheet/` folder; it defaults to the
checkout beside this repository.
"""
import argparse
import datetime
import json
import os
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import recover as rec  # noqa: E402
import registry as reg  # noqa: E402


def default_data():
    env = os.environ.get("BETASHEET_DATA")
    if env:
        return env
    for parent in HERE.parents:
        candidate = parent.parent / "betasheet-data" / "betasheet"
        if (candidate / "sources.json").exists():
            return str(candidate)
    return None


def show_verdict(out):
    verdict = out.get("verdict") or {}
    changes = {k: len(v) for k, v in (verdict.get("changes") or {}).items() if v}
    print("%s  outcome=%s eligible=%s verdict=%s%s%s" % (
        out["source_id"], out.get("outcome"), out.get("eligible"), verdict.get("status"),
        " changes=%s" % changes if changes else "",
        " (reused this run's capture)" if out.get("reused") else ""))
    if out.get("blocked"):
        print("  not baseline-eligible: %s" % out["blocked"])
    if out.get("notice"):
        print("  notice: %s" % out["notice"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", default=default_data())
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("capture")
    p.add_argument("source")
    p.add_argument("--run", required=True)
    p.add_argument("--session", required=True, help="agent-browser session")
    p.add_argument("--by", required=True)
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("ingest")
    p.add_argument("source")
    p.add_argument("--run", required=True)
    p.add_argument("--by", required=True)

    p = sub.add_parser("review")
    p.add_argument("--run", required=True)
    p.add_argument("--gym", required=True)
    p.add_argument("--source", action="append")
    p.add_argument("--all-gyms", action="store_true")
    p.add_argument("--by", required=True)
    p.add_argument("--note", required=True)

    p = sub.add_parser("status")
    p.add_argument("--run", required=True)
    p.add_argument("--gym")

    p = sub.add_parser("close")
    p.add_argument("--run", required=True)
    p.add_argument("--dry-run", action="store_true")

    p = sub.add_parser("register")
    p.add_argument("url")
    p.add_argument("--gym", action="append", required=True)
    p.add_argument("--type", required=True)
    p.add_argument("--id")
    p.add_argument("--origin", default="refresh discovery")

    p = sub.add_parser("recover")
    p.add_argument("--from", dest="run", required=True)
    target = p.add_mutually_exclusive_group(required=True)
    target.add_argument("--out", help="write the proposed registry and report here")
    target.add_argument("--apply", action="store_true", help="replace sources.json")
    p.add_argument("--register-discovered", action="store_true")

    args = parser.parse_args(argv)
    if not args.data or not (pathlib.Path(args.data) / "sources.json").exists():
        parser.error("no sources.json under --data %r" % args.data)
    data = pathlib.Path(args.data)

    try:
        if args.command == "capture":
            show_verdict(reg.capture(data, args.run, args.source, args.by, args.session,
                                     force=args.force))
        elif args.command == "ingest":
            show_verdict(reg.ingest(data, args.run, args.source, args.by))
        elif args.command == "review":
            marked = reg.review(data, args.run, args.gym, args.by, args.note,
                                source_ids=args.source, all_gyms=args.all_gyms)
            print("reviewed for %s: %s" % ("all gyms" if args.all_gyms else args.gym,
                                            ", ".join(marked) or "nothing captured"))
        elif args.command == "status":
            rows = reg.plan(data, args.run)
            for sid, row in rows.items():
                if args.gym and args.gym not in row.get("gyms", []):
                    continue
                record = row.get("record") or {}
                print("%-48s %-10s %-12s %s" % (
                    sid, record.get("outcome", "-"), (row.get("verdict") or {}).get("status", "-"),
                    ("advance: " if row["advance"] else "keep: ") + row["reason"]))
            if args.gym:
                captured = set(rows)
                missing = [s["id"] for s in reg.load(data)
                           if s.get("active") and args.gym in (s.get("gyms") or [])
                           and s["id"] not in captured]
                print("not captured in %s: %s" % (args.run, ", ".join(missing) or "none"))
        elif args.command == "close":
            results, findings = reg.close(data, args.run, dry_run=args.dry_run)
            for sid, row in results.items():
                print("%-48s %s  %s" % (sid, "advanced" if row["advanced"] else "kept    ",
                                        row["reason"]))
            moved = sum(row["advanced"] for row in results.values())
            print("%s%d of %d baselines advanced; %d notice finding(s)" % (
                "dry run: " if args.dry_run else "", moved, len(results), len(findings)))
        elif args.command == "register":
            record, created = reg.register(data, args.url, args.gym, args.type, sid=args.id,
                                           origin=args.origin)
            print("%s %s" % ("registered" if created else "already registered as",
                             record["id"]))
        elif args.command == "recover":
            proposed, report = rec.recover(data, args.run,
                                           register_discovered=args.register_discovered)
            out = (data / "runs" / (datetime.date.today().isoformat() + "-recovery")
                   if args.apply else pathlib.Path(args.out))
            out.mkdir(parents=True, exist_ok=True)
            if args.apply:
                with reg.editing(data) as sources:
                    sources[:] = proposed
            else:
                reg.write_json(out / "sources.json", proposed)
            reg.write_json(out / "recovery-report.json", report)
            (out / "recovery-report.md").write_text(rec.summary(report))
            print(rec.summary(report).split("\n\n")[0])
            print("report: %s" % (out / "recovery-report.md"))
    except reg.RegistryError as exc:
        print("refresh: %s" % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
