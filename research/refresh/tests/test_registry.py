"""Where a baseline lives and when it moves: the registry rules, end to end.

Each case writes a small registry and real capture files, then runs the same functions the
commands use: ingest (extract + compare), review, close. The fixtures are synthetic.
"""
import json
import subprocess
import sys

import coverage
import recover as rec
import registry as reg

RGP = "https://app.rockgympro.com/b/?bo=abc"
MONTHS = ("November 2026", "December 2026", "January 2027")
HEADERS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
GRID = "Select Date\nMo\tTu\tWe\tTh\tFr\tSa\tSu\n26\t27\t28\t29\t30\t31\t1\n"
WEEK1 = ["Thu, November 26, 6 PM to 7 PM", "Thu, December 3, 6 PM to 7 PM"]
WEEK2 = WEEK1 + ["Thu, December 10, 6 PM to 7 PM"]
PAGE = "\n".join("Line %d of a real programme page with a schedule." % n for n in range(12))


# ----------------------------------------------------------------------------- builders

def source(sid="src", gyms=("Gym A",), url=RGP, kind="booking page", **extra):
    record = {"id": sid, "url": url, "type": kind, "gyms": list(gyms), "active": True,
              "origin": "test"}
    record.update(system=reg.system_for(record), aliases=[], baseline=None, ineligible=None,
                  last_attempt=None)
    record["coverage_contract"] = reg.CONTRACT[record["system"]]
    record.update(extra)
    return record


def registry(tmp_path, *sources):
    root = tmp_path / "data"
    root.mkdir()
    reg.write_json(root / "sources.json", list(sources))
    return root


def rgp(root, run, sid, days, read=3, captured_at="2026-11-17T10:00:00+00:00"):
    """A Rock Gym Pro capture that declares its coverage, as tools/rgp.py writes it."""
    folder = reg.source_dir(root, run, sid)
    folder.mkdir(parents=True, exist_ok=True)
    seen = MONTHS[:read]
    data = {"id": sid, "url": RGP, "captured_at": captured_at,
            "months": [{"title": title, "available": [], "clicks": []} for title in seen],
            "series": [{"date_selected": "Date Selected: " + ", ".join(days[0].split(", ")[:2]),
                        "days": list(days)}] if days else [],
            "coverage": coverage.calendar(len(MONTHS), [
                {"title": title, "cells_parsed": 35, "headers": HEADERS} for title in seen])}
    (folder / (sid + ".rgp.json")).write_text(json.dumps(data))
    return folder


def page(folder, name, text, url="https://gym.test/programs"):
    folder.mkdir(parents=True, exist_ok=True)
    meta = {"id": name, "requested_url": url, "final_url": url, "title": "",
            "captured_at": "2026-11-17T10:00:00+00:00", "text_sha256": "0" * 64,
            "text_lines": len([line for line in text.splitlines() if line.strip()])}
    (folder / (name + ".meta.json")).write_text(json.dumps(meta))
    (folder / (name + ".norm.txt")).write_text(text)


def baseline_from_week1(root, sid="src"):
    rgp(root, "w1", sid, WEEK1, captured_at="2026-11-10T10:00:00+00:00")
    reg.ingest(root, "w1", sid, "test")
    reg.review(root, "w1", None, "test", "first read", source_ids=[sid], all_gyms=True)
    results, _ = reg.close(root, "w1")
    assert results[sid]["advanced"], results
    return reg.index(reg.load(root))[sid]["baseline"]


def entry(root, sid="src"):
    return reg.index(reg.load(root))[sid]


# ------------------------------------------------------------------------------- identity

def test_url_normalisation_drops_decoration_only():
    plain = reg.normalise_url("https://ethos.rphq.com/ethos/programs/Kilter%20Class")
    assert reg.normalise_url(
        "https://www.Ethos.rphq.com/ethos/programs/Kilter%20Class/?date=2026-09-12#top") == plain
    assert reg.normalise_url("https://ethos.rphq.com/ethos/programs/kilter-class") != plain
    assert reg.normalise_url(RGP + "&utm_source=ig") == reg.normalise_url(RGP)
    assert reg.normalise_url(RGP) != reg.normalise_url("https://app.rockgympro.com/b/?bo=def")


def test_register_finds_a_decorated_url_and_adds_a_new_one(tmp_path):
    root = registry(tmp_path, source())
    found, created = reg.register(root, RGP + "&utm_source=x", ["Gym A"], "booking page")
    assert (found["id"], created) == ("src", False)
    new, created = reg.register(root, "https://app.rockgympro.com/b/?bo=new", ["Gym A"],
                                "booking page")
    assert created and new["id"] == "gym-a-booking-page" and new["system"] == "rockgympro"
    assert entry(root, new["id"])["baseline"] is None


# ---------------------------------------------------------------------- when it moves

def test_a_first_read_needs_a_review_before_it_becomes_the_baseline(tmp_path):
    root = registry(tmp_path, source())
    rgp(root, "w1", "src", WEEK1)
    assert reg.ingest(root, "w1", "src", "test")["verdict"]["status"] == "new-baseline"
    results, _ = reg.close(root, "w1")
    assert not results["src"]["advanced"] and "awaiting review by Gym A" in results["src"]["reason"]
    assert entry(root)["baseline"] is None
    assert entry(root)["last_attempt"]["verdict"] == "new-baseline"


def test_unchanged_advances_without_a_review(tmp_path):
    root = registry(tmp_path, source())
    baseline_from_week1(root)
    rgp(root, "w2", "src", WEEK1, captured_at="2026-11-17T10:00:00+00:00")
    assert reg.ingest(root, "w2", "src", "test")["verdict"]["status"] == "unchanged"
    results, _ = reg.close(root, "w2")
    assert results["src"]["advanced"]
    assert entry(root)["baseline"]["run"] == "w2"


def test_a_change_waits_for_every_gym_that_cites_the_source(tmp_path):
    root = registry(tmp_path, source(gyms=("Gym A", "Gym B")))
    baseline_from_week1(root)
    rgp(root, "w2", "src", WEEK2)
    assert reg.ingest(root, "w2", "src", "test")["verdict"]["status"] == "changed"

    results, _ = reg.close(root, "w2")
    assert "awaiting review by Gym A, Gym B" in results["src"]["reason"]
    reg.review(root, "w2", "Gym A", "wren", "new Thursday added")
    results, _ = reg.close(root, "w2")
    assert not results["src"]["advanced"] and results["src"]["reason"].endswith("by Gym B")
    assert entry(root)["baseline"]["run"] == "w1"

    reg.review(root, "w2", "Gym B", "sage", "same programme, nothing for Gym B")
    results, _ = reg.close(root, "w2")
    assert results["src"]["advanced"] and entry(root)["baseline"]["run"] == "w2"


def test_a_review_is_bound_to_the_capture_it_saw(tmp_path):
    root = registry(tmp_path, source())
    baseline_from_week1(root)
    folder = rgp(root, "w2", "src", WEEK2)
    reg.ingest(root, "w2", "src", "test")
    reg.review(root, "w2", "Gym A", "wren", "reviewed the first read")
    reg.archive_attempt(folder)  # recaptured after the review
    rgp(root, "w2", "src", WEEK2 + ["Thu, December 17, 6 PM to 7 PM"])
    reg.ingest(root, "w2", "src", "test")
    results, _ = reg.close(root, "w2")
    assert not results["src"]["advanced"] and "awaiting review" in results["src"]["reason"]
    assert (folder / "attempts" / "1" / "src.rgp.json").exists()


# --------------------------------------------------------------- what never moves it

def test_a_failed_capture_keeps_the_baseline_and_records_the_attempt(tmp_path):
    root = registry(tmp_path, source())
    before = baseline_from_week1(root)
    folder = reg.source_dir(root, "w2", "src")
    folder.mkdir(parents=True)
    (folder / "src.rgp.json").write_text(json.dumps(
        {"id": "src", "url": RGP, "captured_at": "2026-11-17T10:00:00+00:00",
         "months": [], "series": []}))
    out = reg.ingest(root, "w2", "src", "test")
    assert out["outcome"] == "failed" and out["verdict"]["status"] == "incomplete"
    reg.review(root, "w2", "Gym A", "wren", "looked at it anyway")
    results, _ = reg.close(root, "w2")
    assert not results["src"]["advanced"]
    assert entry(root)["baseline"] == before
    assert entry(root)["last_attempt"]["outcome"] == "failed"


def test_incomplete_coverage_never_advances_even_when_the_comparison_is_unchanged(tmp_path):
    root = registry(tmp_path, source())
    rgp(root, "w1", "src", [], captured_at="2026-11-10T10:00:00+00:00")
    reg.ingest(root, "w1", "src", "test")
    reg.review(root, "w1", "Gym A", "test", "empty calendar, three months read")
    assert reg.close(root, "w1")[0]["src"]["advanced"]
    before = entry(root)["baseline"]

    rgp(root, "w2", "src", [], read=1)  # one of three months
    out = reg.ingest(root, "w2", "src", "test")
    assert not out["eligible"] and "coverage incomplete" in out["blocked"]
    reg.review(root, "w2", "Gym A", "test", "still empty")
    results, _ = reg.close(root, "w2")
    assert not results["src"]["advanced"] and entry(root)["baseline"] == before

    record = {"outcome": "read-empty", "coverage": {"complete": False}}
    advance, reason = reg.decide(source(), record, {"status": "unchanged"}, {}, "x")
    assert not advance and "coverage incomplete" in reason


def test_a_reconstructed_social_summary_is_never_eligible():
    record = {"outcome": "read", "coverage": {"complete": True, "recovered": True}}
    assert not reg.eligible(record, "instagram")
    assert reg.eligible(record, "rockgympro")


def test_a_notice_is_kept_as_a_finding_and_does_not_move_the_baseline(tmp_path):
    root = registry(tmp_path, source(url="https://gym.test/programs", kind="web page"))
    page(reg.source_dir(root, "w1", "src"), "src", PAGE)
    reg.ingest(root, "w1", "src", "test")
    reg.review(root, "w1", "Gym A", "test", "first read")
    assert reg.close(root, "w1")[0]["src"]["advanced"]

    page(reg.source_dir(root, "w2", "src"), "src", "This plan is inactive.\n" + PAGE)
    reg.ingest(root, "w2", "src", "test")
    results, findings = reg.close(root, "w2")
    assert not results["src"]["advanced"] and entry(root)["baseline"]["run"] == "w1"
    assert findings == [{"source_id": "src", "notice": "plan-inactive",
                         "evidence": ["runs/w2/sources/src/src.meta.json"]}]


def test_registry_writes_hold_an_exclusive_lock(tmp_path):
    root = registry(tmp_path, source())
    probe = ("import fcntl, sys\n"
             "handle = open(sys.argv[1], 'a')\n"
             "fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)\n")
    lock = str(root / "sources.json.lock")
    with reg.editing(root) as sources:
        sources[0]["note"] = "edited"
        assert subprocess.run([sys.executable, "-c", probe, lock],
                              capture_output=True).returncode != 0
    assert subprocess.run([sys.executable, "-c", probe, lock]).returncode == 0
    assert entry(root)["note"] == "edited"


# -------------------------------------------------------------------------------- recovery

def test_recovery_keeps_only_captures_that_prove_what_they_read(tmp_path):
    run = "2026-11-11-refresh"
    evidence = tmp_path / "data" / "runs" / run / "gyms" / "gym-a" / "evidence"
    old = "runs/%s/gyms/gym-a/evidence/" % run
    root = registry(
        tmp_path,
        dict(source("cal", url="https://app.rockgympro.com/b/?bo=cal"),
             last_copy=old + "cal.rgp.json"),
        dict(source("shell", url="https://gym.test/a", kind="web page"),
             last_copy=old + "shell.norm.txt", last_checked="2026-11-12"),
        dict(source("ig", url="https://www.instagram.com/gymhandle/", kind="instagram"),
             last_copy=old + "ig-gymhandle.md"),
        source("notice", url="https://gym.test/b", kind="web page"))
    evidence.mkdir(parents=True)
    (evidence / "cal.rgp.json").write_text(json.dumps(
        {"id": "cal", "url": "https://app.rockgympro.com/b/?bo=cal",
         "captured_at": "2026-11-12T14:00:00+00:00",
         "months": [{"title": title, "available": []} for title in MONTHS], "series": []}))
    (evidence / "cal.rgp.txt").write_text(GRID)
    page(evidence, "shell", "Performing security verification\nThis may take a moment.",
         url="https://gym.test/a")
    page(evidence, "notice", "There is nothing here.\n" + PAGE, url="https://gym.test/b")
    (evidence / "ig-gymhandle.md").write_text(
        "# Instagram\n\nurl: https://www.instagram.com/gymhandle/\n"
        "captured_at: 2026-11-12T15:00:00Z\n\n"
        "newest post: https://www.instagram.com/gymhandle/p/DfnKjHABuJI/\n\n"
        "## candidate posts\n\n"
        "- 2026-11-11 | https://www.instagram.com/gymhandle/p/DfnKjHABuJI/ | Gym\n")
    cells = [{"label": "November %d, 2026" % (day + 1), "state": "unmarked"} for day in range(30)]
    cells[20] = {"label": "November 21, 2026, Available", "state": "available"}
    (evidence / "camp.rphq.json").write_text(json.dumps(
        {"id": "camp", "url": "https://gym.rphq.com/gym/programs/winter-camp",
         "captured_at": "2026-11-12T15:00:00+00:00",
         "months": [{"title": "November 2026", "cells": cells,
                     "available": ["November 21, 2026, Available"]}],
         "available": ["November 21, 2026, Available"], "details": {}}))

    proposed, report = rec.recover(root, run, register_discovered=True)
    by_id = reg.index(proposed)

    assert by_id["cal"]["baseline"]["outcome"] == "read-empty"
    assert by_id["cal"]["baseline"]["recovered"] is True
    assert by_id["shell"]["baseline"] is None
    assert by_id["shell"]["ineligible"]["capture"] == old + "shell.meta.json"
    assert "security-verification" in by_id["shell"]["ineligible"]["reason"]
    assert by_id["ig"]["baseline"] is None
    assert by_id["ig"]["last_attempt"]["outcome"] == "partial"
    assert by_id["ig"]["last_attempt"]["post_ids"] == ["DfnKjHABuJI"]
    assert by_id["notice"]["baseline"] is None
    assert {"source_id": "notice", "notice": "nothing-here",
            "evidence": [old + "notice.meta.json"]} in report["findings"]
    assert by_id["camp"]["system"] == "redpoint" and by_id["camp"]["gyms"] == ["Gym A"]
    assert by_id["camp"]["baseline"]["outcome"] == "read"
    for record in proposed:
        assert not set(reg.FOLDED) & {"last_copy", "fingerprint", "last_checked"} & set(record)
    assert reg.load(root)[0]["last_copy"] == old + "cal.rgp.json"  # nothing written
