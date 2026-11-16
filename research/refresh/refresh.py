#!/usr/bin/env python3
"""The weekly refresh's registry commands. See REGISTRY.md.

    refresh.py capture  <id> --run R --session S --by NAME [--force]
    refresh.py ingest   <id> --run R --by NAME
    refresh.py findings [--gym G] [--source ID] [--all]
    refresh.py review   (--gym G ... | --all-gyms) (--run R [--source ID ...] | --finding REF ...)
                        --outcome no-change|held|proposed [--proposal GYM/REF [--proposal-run R]]
                        --by NAME --note TEXT
    refresh.py status   --run R [--gym G]
    refresh.py close    --run R [--dry-run]
    refresh.py register <url> --gym G [--gym G2] --type T [--id ID]
    refresh.py recover  --from RUN [--out DIR | --apply] [--register-discovered]

`--data` (or $BETASHEET_DATA) is betasheet-data's `betasheet/` folder; it defaults to the
checkout beside this repository.
"""
import argparse
import datetime
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
    print("%s  outcome=%s eligible=%s compared-with=%s verdict=%s%s%s" % (
        out["source_id"], out.get("outcome"), out.get("eligible"),
        (out.get("baseline") or {}).get("slot"), verdict.get("status"),
        " changes=%s" % changes if changes else "",
        " (reused this run's capture)" if out.get("reused") else ""))
    if out.get("blocked"):
        print("  not baseline-eligible: %s" % out["blocked"])
    if out.get("notice"):
        print("  notice: %s" % out["notice"])
    for ref in out.get("findings") or []:
        print("  finding saved for %s: %s" % (", ".join(out.get("gyms") or []), ref))


def show_finding(finding):
    print("%s  [%s] %s, %s, %s%s" % (
        finding["ref"], finding.get("status"), finding.get("gym"), finding.get("run"),
        finding.get("kind"), ", %s" % finding["shown_now"] if finding.get("shown_now") else ""))
    print("  %s" % finding.get("summary"))
    print("  evidence: %s" % ", ".join(finding.get("evidence") or []))
    if finding.get("proposal"):
        state = finding.get("proposal_state") or {}
        print("  proposal: %s in %s, %s" % (
            finding["proposal"]["ref"], finding["proposal"]["file"],
            "published as #%s (%s)" % (state.get("listing_id"), state.get("receipt"))
            if state.get("state") == "published" else state.get("state", "linked")))
        if state.get("same_ref_other_runs"):
            print("  not this proposal: the same ref was published from %s" % ", ".join(
                state["same_ref_other_runs"]))


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

    p = sub.add_parser("findings")
    p.add_argument("--gym")
    p.add_argument("--source")
    p.add_argument("--all", action="store_true", help="include resolved findings")

    p = sub.add_parser("review")
    p.add_argument("--gym", action="append", default=[])
    p.add_argument("--all-gyms", action="store_true")
    p.add_argument("--run")
    p.add_argument("--source", action="append")
    p.add_argument("--finding", action="append")
    p.add_argument("--outcome", required=True, choices=sorted(reg.DISPOSITIONS))
    p.add_argument("--by", required=True)
    p.add_argument("--note", required=True)
    p.add_argument("--proposal", help="with --outcome proposed: the proposal that carries the "
                   "work, <gym-folder>/<ref>, or its bare ref when one --gym is named")
    p.add_argument("--proposal-run", help="the run whose proposal files hold it, when that is "
                   "a later run than the findings' own (a proposal carried forward)")

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
        elif args.command == "findings":
            found = reg.open_findings(data, gym=args.gym, source_id=args.source,
                                      include_resolved=args.all)
            for finding in found:
                show_finding(finding)
            print("%d finding(s)%s" % (len(found), "" if args.all else " unresolved"))
        elif args.command == "review":
            done = reg.review(data, args.gym, args.by, args.note, outcome=args.outcome,
                              run=args.run, source_ids=args.source, refs=args.finding,
                              all_gyms=args.all_gyms, proposal=args.proposal,
                              proposal_run=args.proposal_run)
            for row in done:
                link = row["proposal"]
                print("%s  %s: %s%s" % (row["ref"], row["gym"], row["status"],
                                        " -> %s (run %s)" % (link["ref"], link["run"]) if link else ""))
            print("%d disposition(s) recorded" % len(done))
        elif args.command == "status":
            rows = reg.plan(data, args.run)
            for sid, row in rows.items():
                if args.gym and args.gym not in row.get("gyms", []):
                    continue
                record = row.get("record") or {}
                print("%-48s %-10s %-12s %s%s" % (
                    sid, record.get("outcome", "-"), (row.get("verdict") or {}).get("status", "-"),
                    ("moves %s: " % row["slot"]) if row["slot"] else "keeps baselines: ",
                    row["reason"]))
            sources = reg.load(data)
            if args.gym:
                missing = [s["id"] for s in sources
                           if s.get("active") and args.gym in (s.get("gyms") or [])
                           and s["id"] not in rows]
                print("not captured in %s: %s" % (args.run, ", ".join(missing) or "none"))
                gaps = [g["source_id"] for g in reg.calendar_gaps(sources) if args.gym in g["gyms"]]
                print("calendar gaps: %s" % (", ".join(gaps) or "none"))
                queue = [q["source_id"] for q in reg.recapture_queue(sources) if args.gym in q["gyms"]]
                print("recapture (calendar baseline is dates only): %s" % (", ".join(queue) or "none"))
                print("unresolved findings: %d" % len(reg.open_findings(data, gym=args.gym)))
        elif args.command == "close":
            results, pending, gaps = reg.close(data, args.run, dry_run=args.dry_run)
            for sid, row in results.items():
                print("%-48s %-14s %s" % (sid, row["advanced"] or "kept", row["reason"]))
            moved = sum(bool(row["advanced"]) for row in results.values())
            print("%s%d of %d sources moved a baseline; %d calendar gap(s); %d unresolved finding(s)"
                  % ("dry run: " if args.dry_run else "", moved, len(results), len(gaps),
                     len(pending)))
        elif args.command == "register":
            record, created = reg.register(data, args.url, args.gym, args.type, sid=args.id,
                                           origin=args.origin)
            print("%s %s" % ("registered" if created else "already registered as",
                             record["id"]))
        elif args.command == "recover":
            if args.apply and rec.already_recovered(reg.load(data)):
                raise reg.RegistryError(
                    "this registry is already recovered: it has baselines and no November "
                    "pointers, so a second pass would reset every baseline to its November "
                    "capture. Apply recovery once; a dry run (--out DIR) still runs.")
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
            print(rec.summary(report).split("\n\n")[1])
            print("report: %s" % (out / "recovery-report.md"))
    except reg.RegistryError as exc:
        print("refresh: %s" % exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
