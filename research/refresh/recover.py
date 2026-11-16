"""One-time recovery: rebuild each source's baselines from a past run's captures.

The November registry pointed at files without saying what they proved. Recovery reads every
capture in the run with `extract()`, matches it to a source id, and keeps as a baseline only a
capture that read its source and met its coverage. A calendar source gets its calendar
baseline and, separately, a page baseline from a read that found only the offering's text,
with its calendar gap noted. Nothing is attached by resemblance, and no evidence file is moved
or changed. See REGISTRY.md.
"""
import collections
import pathlib

import compare
import extract as ex
import registry as reg

GLOBS = ("*.rgp.json", "*.rphq.json", "*.meta.json", "*.ig.json", "*.fb.json", "ig-*.md",
         "fb-*.md")
SUFFIXES = (".rgp.json", ".rphq.json", ".meta.json", ".ig.json", ".fb.json")


def capture_files(run_path):
    roots = sorted(run_path.glob("gyms/*/evidence")) + sorted(run_path.glob("shared/*/evidence"))
    for root in roots:
        for pattern in GLOBS:
            yield from sorted(root.glob(pattern))


def stem(path):
    name = path.name
    for suffix in SUFFIXES:
        if name.endswith(suffix):
            return name[:-len(suffix)]
    return name[3:-3]  # ig-<id>.md / fb-<id>.md


def capture_url(path, record):
    if record.get("url"):
        return record["url"]
    if path.suffix == ".json":
        return (reg.read_json(path) or {}).get("url")
    for line in path.read_text(errors="replace").splitlines()[:12]:
        if line.lower().startswith("url:"):
            return line.split(":", 1)[1].strip()
    return None


def pointer(path):
    """The capture file `extract()` reads for a November `last_copy`."""
    if path and path.endswith(".norm.txt"):
        return path[:-len(".norm.txt")] + ".meta.json"
    return path


def gym_names(sources):
    return {reg.slug(gym): gym for source in sources for gym in source.get("gyms") or []}


def newest(items):
    return max(items, key=lambda item: item["record"].get("captured_at") or "")


def assign_baselines(data, run, source, system, mine, report):
    """Set a source's baselines from its own run captures: the newest eligible capture for
    each slot. A calendar source also records whether its calendar is still a gap."""
    for field in ("baseline", "page_baseline") if system in reg.CALENDAR else ("baseline",):
        source[field] = None
    slots = collections.defaultdict(list)
    for item in mine:
        if reg.eligible(item["record"], system):
            slots[reg.slot_for(item["record"], system)].append(item)
    for slot, items in slots.items():
        best = newest(items)
        check = compare.compare_source(best["record"], best["record"])
        if check["status"] != compare.UNCHANGED:
            report["self_compare_failures"].append({"id": source["id"], "capture": best["capture"],
                                                    "status": check["status"]})
        source[slot] = reg.baseline_facts(data, best["record"], best["capture"], run,
                                          check.get("fingerprint"), recovered=True)
        unverified = source[slot].get("slot_coverage")
        report["baselines"].append({"id": source["id"], "system": system, "slot": slot,
                                    "outcome": best["record"]["outcome"],
                                    "evidence": best["record"].get("evidence"),
                                    "slot_coverage": unverified})
        if unverified:  # the queue is keyed by the evidence file, then by its source id
            report["recapture"].append({
                "capture": best["capture"], "capture_id": stem(best["path"]),
                "id": source["id"], "gyms": source.get("gyms") or [],
                "slot_coverage": unverified, "why": reg.UNVERIFIED_SLOTS[unverified],
                "sessions": len(best["record"].get("entries") or [])})
    if system in reg.CALENDAR:
        last = newest(mine) if mine else None
        if last and reg.calendar_seen(last["record"]):
            source["calendar_gap"] = None
        else:
            why = ("calendar markup not observed; page text read"
                   if last and reg.page_only(last["record"], system) else
                   reg.why_not(last["record"], system) if last else "no capture in %s" % run)
            source["calendar_gap"] = {"since_run": run, "last_run": run, "reason": why}


def recover(data, run, register_discovered=False):
    """Returns (proposed sources list, report). Writes nothing."""
    data = pathlib.Path(data)
    run_path = data / "runs" / run
    sources = reg.load(data)
    ids = {source["id"] for source in sources}
    by_pointer = collections.defaultdict(list)
    for source in sources:
        if source.get("last_copy"):
            by_pointer[pointer(source["last_copy"])].append(source)
    by_url = collections.defaultdict(list)
    for source in sources:
        by_url[reg.normalise_url(source["url"])].append(source["id"])

    candidates = collections.defaultdict(list)
    report = collections.defaultdict(list)
    tally, files = collections.Counter(), set()
    for path in capture_files(run_path):
        rel = reg.relative(data, path)
        files.add(rel)
        try:
            record = ex.extract(str(path))
        except Exception as exc:  # an unreadable file is reported, never guessed at
            report["unreadable"].append({"capture": rel, "error": str(exc)[:200]})
            tally[(reg.capture_kind(path), "unreadable")] += 1
            continue
        tally[(reg.capture_kind(path), record.get("outcome"))] += 1
        url = capture_url(path, record)
        item = {"path": path, "capture": rel, "record": record, "url": url,
                "kind": reg.capture_kind(path)}
        owners = by_pointer.get(rel, [])
        if len(owners) > 1:  # one file under two ids: it belongs to the one whose URL it read
            owners = [o for o in owners if url and
                      reg.normalise_url(o["url"]) == reg.normalise_url(url)]
        if len(owners) == 1:
            sid, how = owners[0]["id"], "pointer"
        elif stem(path) in ids:
            sid, how = stem(path), "id"
        else:
            hits = by_url.get(reg.normalise_url(url), []) if url else []
            sid, how = (hits[0], "url") if len(hits) == 1 else (None, "ambiguous" if hits else None)
        if sid:
            candidates[sid].append(item)
        elif how == "ambiguous":
            report["ambiguous"].append({"capture": rel, "url": url,
                                        "sources": by_url[reg.normalise_url(url)]})
        else:
            item["gym"] = path.parent.parent.name
            report["discovered"].append(item)

    matched = {item["capture"]: sid for sid, items in candidates.items() for item in items}
    findings = collections.OrderedDict()
    proposed = []
    for source in sources:
        source = dict(source)
        old = pointer(source.get("last_copy"))
        old_checked = source.get("last_checked")
        items = candidates.get(source["id"], [])
        for item in items:
            if item["record"].get("notice"):
                key = (source["id"], item["record"]["notice"])
                findings.setdefault(key, []).append(item["capture"])
        system = reg.system_for(source, [item["kind"] for item in items])
        mine = [i for i in items if i["kind"] == system]
        for field in reg.FOLDED:
            source.pop(field, None)
        source["system"] = system
        source["coverage_contract"] = reg.CONTRACT[system]
        source.setdefault("aliases", [])
        source["ineligible"] = source["last_attempt"] = None
        assign_baselines(data, run, source, system, mine, report)
        if mine:
            last = newest(mine)
            outcome = last["record"].get("outcome")
            if system in reg.SOCIAL and not reg.eligible(last["record"], system):
                outcome = ex.PARTIAL  # a summary is partial evidence until a social-window read
            source["last_attempt"] = {"run": run, "capture": last["capture"],
                                      "captured_at": last["record"].get("captured_at"),
                                      "outcome": outcome,
                                      "evidence": last["record"].get("evidence"),
                                      "verdict": None, "recovered": True}
            if system in reg.SOCIAL:
                source["last_attempt"]["post_ids"] = [
                    p["id"] for p in last["record"].get("posts") or [] if p.get("id")]
        if old and not source["baseline"]:
            old_item = next((i for i in items if i["capture"] == old), None)
            if old_item is None and old in matched:
                reason = "the capture belongs to %s" % matched[old]
            elif old_item is None:
                reason = "not a capture file extract() reads"
            elif old_item["kind"] != system:
                reason = "a %s capture cannot be a %s baseline" % (old_item["kind"], system)
            elif reg.page_only(old_item["record"], system):
                reason = "page text only; kept as the page baseline, calendar not observed"
            else:
                reason = reg.why_not(old_item["record"], system)
            if reason:
                source["ineligible"] = {"capture": old,
                                        "outcome": old_item["record"].get("outcome")
                                        if old_item else None,
                                        "reason": reason, "since": old_checked}
                report["ineligible"].append({"id": source["id"], "capture": old,
                                             "reason": reason})
        if not source["baseline"]:
            why = ("no capture in %s" % run if not items else
                   "captures are not %s" % system if not mine else
                   "page baseline only; calendar not observed" if source.get("page_baseline") else
                   reg.why_not(newest(mine)["record"], system))
            if not mine and items and system == "page":
                kinds = sorted({i["kind"] for i in items})
                why = "discovery page captured as %s; capture it as a page" % "/".join(kinds)
            report["no_baseline"].append({"id": source["id"], "system": system, "reason": why})
        proposed.append(source)

    names = gym_names(sources)
    discovered = []
    for item in report.pop("discovered", []):
        record = item["record"]
        entry = {"capture": item["capture"], "url": item["url"], "kind": item["kind"],
                 "gym": names.get(item["gym"], item["gym"]), "outcome": record.get("outcome"),
                 "notice": record.get("notice"), "proposed_id": stem(item["path"])}
        if record.get("notice"):
            findings.setdefault((None, record["notice"]), []).append(item["capture"])
        if register_discovered and item["kind"] not in reg.SOCIAL and item["url"]:
            sid = entry["proposed_id"]
            if sid in ids:
                sid = "%s-%s" % (reg.slug(entry["gym"]), sid)
            kind = "web page" if item["kind"] == "page" else "booking page"
            new = {"id": sid, "url": item["url"], "type": kind, "gyms": [entry["gym"]],
                   "active": True, "origin": "%s followed link" % run}
            system = reg.system_for(new, [item["kind"]])
            new.update(system=system, coverage_contract=reg.CONTRACT[system], aliases=[],
                       ineligible=None,
                       last_attempt={"run": run, "capture": item["capture"],
                                     "captured_at": record.get("captured_at"),
                                     "outcome": record.get("outcome"),
                                     "evidence": record.get("evidence"), "verdict": None,
                                     "recovered": True})
            assign_baselines(data, run, new, system,
                             [item] if item["kind"] == system else [], report)
            proposed.append(new)
            ids.add(sid)
            entry["registered_as"] = sid
        discovered.append(entry)
    report["discovered"] = discovered
    report["captures"] = [{"kind": kind, "outcome": outcome, "count": count}
                          for (kind, outcome), count in sorted(tally.items())]

    # Account for every capture file: each is a baseline, a last attempt, an ineligible old
    # pointer, a discovered or ambiguous capture, unreadable, or listed here with the reason
    # it was not used, so none drops out of the registry without a trace.
    used = {(source.get(field) or {}).get("capture") for source in proposed
            for field in ("baseline", "page_baseline", "last_attempt", "ineligible")}
    used |= {entry["capture"] for key in ("discovered", "ambiguous", "unreadable")
             for entry in report.get(key, [])}
    systems = {source["id"]: source.get("system") for source in proposed}
    for sid, items in sorted(candidates.items()):
        for item in items:
            if item["capture"] in used:
                continue
            report["unused"].append({
                "capture": item["capture"], "id": sid, "kind": item["kind"],
                "outcome": item["record"].get("outcome"),
                "reason": ("a %s capture of a %s source" % (item["kind"], systems.get(sid))
                           if item["kind"] != systems.get(sid) else "an older capture")})
            used.add(item["capture"])
    report["accounted"] = {"files": len(files), "accounted": len(used & files)}
    report["findings"] = [{"source_id": sid, "notice": notice, "evidence": evidence}
                          for (sid, notice), evidence in findings.items()]
    return proposed, dict(report)


def summary(report):
    """Counts a reviewer can check against the evidence."""
    count = collections.Counter
    lines = ["# Baseline recovery", ""]
    captures = report.get("captures", [])
    lines += ["Capture files read: %d" % sum(c["count"] for c in captures)]
    lines += ["- %s %s: %d" % (c["kind"], c["outcome"], c["count"]) for c in captures]
    base = count((b["system"], b["slot"], b["outcome"] + (" (%s)" % b["slot_coverage"]
                                                          if b.get("slot_coverage") else ""))
                 for b in report.get("baselines", []))
    lines += ["", "Baselines recovered: %d" % sum(base.values())]
    lines += ["- %s %s %s: %d" % (system, slot, outcome, n)
              for (system, slot, outcome), n in sorted(base.items())]
    queue = report.get("recapture", [])
    renamed = [q for q in queue if q["capture_id"] != q["id"]]
    kinds = count(q["slot_coverage"] for q in queue)
    lines += ["", "Recapture queue: %d Rock Gym Pro calendars whose baseline is a legacy capture: "
              "%d dates-only (dates are evidence; one session was kept per date; %d sessions "
              "recorded) and %d availability-unverified (an empty grid read without the paint "
              "check); %d recorded under a capture id that is not the source id" % (
                  len(queue), kinds["dates-only"],
                  sum(q["sessions"] for q in queue if q["slot_coverage"] == "dates-only"),
                  kinds["availability-unverified"], len(renamed))]
    lines += ["- %s <- %s (%s, %d sessions%s)" % (q["id"], q["capture"], q["slot_coverage"],
                                                 q["sessions"], "; capture id %s" % q["capture_id"]
                                                 if q["capture_id"] != q["id"] else "")
              for q in sorted(queue, key=lambda q: q["id"])]
    lines += ["", "Old pointers kept as ineligible: %d" % len(report.get("ineligible", []))]
    lines += ["- %s: %s" % (i["id"], i["reason"]) for i in report.get("ineligible", [])]
    reasons = count(n["reason"].split(" (")[0] for n in report.get("no_baseline", []))
    lines += ["", "No calendar or main baseline: %d" % len(report.get("no_baseline", []))]
    lines += ["- %s: %d" % (reason, n) for reason, n in reasons.most_common()]
    lines += ["", "Captures with no source: %d" % len(report.get("discovered", []))]
    lines += ["- %s %s (%s, %s)%s" % (d["kind"], d["capture"], d["gym"], d["outcome"],
                                       " -> registered as %s" % d["registered_as"]
                                       if d.get("registered_as") else "")
              for d in report.get("discovered", [])]
    unused = report.get("unused", [])
    lines += ["", "Matched captures not used as a baseline or last attempt: %d" % len(unused)]
    lines += ["- %s <- %s (%s %s): %s" % (u["id"], u["capture"], u["kind"], u["outcome"],
                                          u["reason"]) for u in unused]
    accounted = report.get("accounted") or {}
    lines += ["", "Capture files accounted for: %s of %s" % (accounted.get("accounted"),
                                                          accounted.get("files"))]
    for key in ("ambiguous", "unreadable", "self_compare_failures"):
        lines += ["", "%s: %d" % (key.replace("_", " ").capitalize(), len(report.get(key, [])))]
        lines += ["- %s" % entry for entry in report.get(key, [])]
    lines += ["", "Findings (notices): %d" % len(report.get("findings", []))]
    lines += ["- %s: %s (%d file%s)" % (f["source_id"], f["notice"], len(f["evidence"]),
                                        "" if len(f["evidence"]) == 1 else "s")
              for f in report.get("findings", [])]
    return "\n".join(lines) + "\n"
