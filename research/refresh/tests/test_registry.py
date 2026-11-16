"""Where baselines live, when they move, and how unresolved changes survive: end to end.

Each case writes a small registry and real capture files, then runs the functions the
commands use: ingest (extract + compare + save findings), review, close. Fixtures are
synthetic, shaped like the capture tools' output.
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
CAMP = "Winter Youth Camp: January 5 to February 23, register now."
OFFERING = ("Gym Inc\n1 Main St\n555-555-5555\nTeen Climbing Club\n"
            "Weekly coached sessions for climbers aged 12 to 17, all levels welcome.\n"
            "Powered by Rock Gym Pro\n")
SHARED = ("Gym A", "Gym B", "Gym C")


# ----------------------------------------------------------------------------- builders

def source(sid="src", gyms=("Gym A",), url=RGP, kind="booking page", **extra):
    record = {"id": sid, "url": url, "type": kind, "gyms": list(gyms), "active": True,
              "origin": "test"}
    record.update(system=reg.system_for(record), aliases=[], baseline=None, ineligible=None,
                  last_attempt=None)
    if record["system"] in reg.CALENDAR:
        record.update(page_baseline=None, calendar_gap=None)
    record["coverage_contract"] = reg.CONTRACT[record["system"]]
    record.update(extra)
    return record


def registry(tmp_path, *sources):
    root = tmp_path / "data"
    root.mkdir()
    reg.write_json(root / "sources.json", list(sources))
    return root


def rgp(root, run, sid, days, read=3, captured_at="2026-11-17T10:00:00+00:00"):
    """A Rock Gym Pro calendar capture that declares its coverage, as tools/rgp.py writes."""
    folder = reg.new_attempt_folder(root, run, sid)
    seen = MONTHS[:read]
    data = {"id": sid, "url": RGP, "captured_at": captured_at,
            "months": [{"title": title, "available": [], "clicks": []} for title in seen],
            "series": [{"date_selected": "Date Selected: " + ", ".join(days[0].split(", ")[:2]),
                        "days": list(days)}] if days else [],
            "coverage": coverage.calendar(len(MONTHS), [
                {"title": title, "cells_parsed": 35, "headers": HEADERS} for title in seen])}
    (folder / (sid + ".rgp.json")).write_text(json.dumps(data))
    return folder


def rgp_page_only(root, run, sid, text=OFFERING, captured_at="2026-11-17T10:00:00+00:00"):
    """An offering page whose calendar markup never appeared: description text only.
    (Shaped like November's captures, which declare no calendar coverage.)"""
    folder = reg.new_attempt_folder(root, run, sid)
    (folder / (sid + ".rgp.json")).write_text(json.dumps(
        {"id": sid, "url": RGP, "captured_at": captured_at, "months": [], "series": []}))
    (folder / (sid + ".rgp.txt")).write_text(text)
    return folder


def page(folder, name, text, url="https://gym.test/programs"):
    folder.mkdir(parents=True, exist_ok=True)
    meta = {"id": name, "requested_url": url, "final_url": url, "title": "",
            "captured_at": "2026-11-17T10:00:00+00:00", "text_sha256": "0" * 64,
            "text_lines": len([line for line in text.splitlines() if line.strip()])}
    (folder / (name + ".meta.json")).write_text(json.dumps(meta))
    (folder / (name + ".norm.txt")).write_text(text)


def ig(root, run, sid, shortcodes, requested=2, anchor=None):
    """A structured Instagram capture, as tools/social_ig.py writes it."""
    folder = reg.new_attempt_folder(root, run, sid)
    posts = [{"id": code, "url": "https://www.instagram.com/p/%s/" % code,
              "published": "2026-11-%02d" % (20 - n),
              "caption": "Caption for post %s with enough words to be read in full." % code,
              "alts": []} for n, code in enumerate(shortcodes)]
    reached = bool(anchor) and anchor in shortcodes
    (folder / (sid + ".ig.json")).write_text(json.dumps(
        {"id": sid, "provider": "instagram", "url": "https://www.instagram.com/gymhandle/",
         "captured_at": "2026-11-17T10:00:00+00:00", "posts": posts,
         "coverage": {"contract": "social-window", "posts_requested": requested,
                      "posts_fully_read": len(posts), "anchor_id": anchor,
                      "anchor_reached": reached if anchor else None,
                      "stopping_post": shortcodes[-1] if shortcodes else None,
                      "stopped_reason": "declared-limit", "challenge_detected": None,
                      "complete": len(posts) >= requested and (reached if anchor else True),
                      "errors": []}}))


def first_run(root, sid="src", days=WEEK1):
    rgp(root, "w1", sid, days, captured_at="2026-11-10T10:00:00+00:00")
    reg.ingest(root, "w1", sid, "test")
    results, _, _ = reg.close(root, "w1")
    assert results[sid]["advanced"] == "baseline", results
    return entry(root, sid)["baseline"]


def entry(root, sid="src"):
    return reg.index(reg.load(root))[sid]


def held(root, gym, run=None):
    """The registry findings in a gym's decisions.json, by ref."""
    return {record["ref"]: record for _, record in reg.all_findings(root)
            if record["gym"] == gym and (run is None or record["run"] == run)}


# ------------------------------------------------------------------------------- identity

def test_url_normalisation_drops_decoration_only():
    plain = reg.normalise_url("https://ethos.rphq.com/ethos/programs/Kilter%20Class")
    assert reg.normalise_url(
        "https://www.Ethos.rphq.com/ethos/programs/Kilter%20Class/?date=2026-09-12#top") == plain
    assert reg.normalise_url("https://ethos.rphq.com/ethos/programs/kilter-class") != plain
    assert reg.normalise_url(RGP + "&utm_source=ig") == reg.normalise_url(RGP)
    assert reg.normalise_url(RGP) != reg.normalise_url("https://app.rockgympro.com/b/?bo=def")


def test_a_widget_index_is_a_discovery_page_and_an_offering_is_a_calendar():
    assert reg.system_for({"url": "https://app.rockgympro.com/b/?bw=f5d8"}) == "page"
    assert reg.system_for({"url": RGP}) == "rockgympro"
    assert reg.system_for({"url": "https://app.rockgympro.com/b/widget/?a=offering"
                                  "&offering_guid=70ba&mode=p"}) == "rockgympro"
    assert reg.system_for({"url": "https://ethos.rphq.com/ethos/n/classes"}) == "page"
    assert reg.system_for({"url": "https://portal.gym.ca/x/programs/camp"}, ["redpoint"]) == \
        "redpoint"


def test_register_finds_a_decorated_url_and_adds_a_new_one(tmp_path):
    root = registry(tmp_path, source())
    found, created = reg.register(root, RGP + "&utm_source=x", ["Gym A"], "booking page")
    assert (found["id"], created) == ("src", False)
    new, created = reg.register(root, "https://app.rockgympro.com/b/?bo=new", ["Gym A"],
                                "booking page")
    assert created and new["id"] == "gym-a-booking-page" and new["system"] == "rockgympro"
    assert entry(root, new["id"])["page_baseline"] is None


# ------------------------------------------- findings are saved, then the baseline moves

def test_a_first_read_saves_a_finding_and_becomes_the_baseline_without_review(tmp_path):
    root = registry(tmp_path, source())
    rgp(root, "w1", "src", WEEK1)
    out = reg.ingest(root, "w1", "src", "test")
    assert out["verdict"]["status"] == "new-baseline" and len(out["findings"]) == 1
    finding = held(root, "Gym A")[out["findings"][0]]
    assert finding["kind"] == "source_first_read" and finding["status"] == "pending"
    assert "2 bookable entries from 2026-11-26 to 2026-12-03" in finding["summary"]

    results, _, _ = reg.close(root, "w1")
    assert results["src"]["advanced"] == "baseline" and entry(root)["baseline"]["run"] == "w1"


def test_unchanged_advances_and_saves_nothing(tmp_path):
    root = registry(tmp_path, source())
    first_run(root)
    rgp(root, "w2", "src", WEEK1)
    assert reg.ingest(root, "w2", "src", "test")["findings"] == []
    assert reg.close(root, "w2")[0]["src"]["advanced"] == "baseline"
    assert entry(root)["baseline"]["run"] == "w2" and len(held(root, "Gym A", "w2")) == 0


def test_a_change_is_saved_with_its_evidence_before_the_baseline_moves(tmp_path):
    root = registry(tmp_path, source())
    before = first_run(root)
    rgp(root, "w2", "src", WEEK2)
    out = reg.ingest(root, "w2", "src", "test")
    finding = held(root, "Gym A", "w2")[out["findings"][0]]
    assert finding["kind"] == "source_change" and finding["status"] == "pending"
    assert finding["source_id"] == "src" and finding["gym"] == "Gym A"
    assert finding["summary"] == "Calendar changed: 1 session(s) added: 2026-12-10 18:00-19:00."
    assert finding["capture_sha256"] == out["capture_sha256"]
    assert finding["evidence"] == [before["capture"], out["capture"]]
    assert (root / finding["evidence"][0]).exists() and (root / finding["evidence"][1]).exists()

    results, _, _ = reg.close(root, "w2")  # nobody has reviewed it
    assert results["src"]["advanced"] == "baseline" and entry(root)["baseline"]["run"] == "w2"
    assert held(root, "Gym A", "w2")[out["findings"][0]]["status"] == "pending"


def test_a_pending_change_survives_its_disappearance_from_the_source(tmp_path):
    root = registry(tmp_path, source(url="https://gym.test/camps", kind="web page"))
    for run, text in (("w1", PAGE), ("w2", PAGE + "\n" + CAMP), ("w3", PAGE)):
        page(reg.source_dir(root, run, "src"), "src", text, url="https://gym.test/camps")
        reg.ingest(root, run, "src", "test")
        assert reg.close(root, run)[0]["src"]["advanced"] == "baseline"

    pending = {f["run"]: f for f in reg.open_findings(root, gym="Gym A")
               if f["kind"] == "source_change"}
    announced, withdrawn = pending["w2"], pending["w3"]
    assert announced["summary"] == ("Page content changed; interpretation pending. "
                                    "New text includes “%s”." % CAMP)
    assert announced["details"]["lines_added"] == [CAMP]
    assert announced["shown_now"] == "no longer shown"
    assert withdrawn["details"]["lines_removed"] == [CAMP]
    assert set(announced["evidence"]) == {"runs/w1/sources/src/src.meta.json",
                                          "runs/w2/sources/src/src.meta.json"}
    close = reg.read_json(reg.run_dir(root, "w3") / "close.json")
    assert announced["ref"] in {f["ref"] for f in close["pending_findings"]}


def test_a_shared_source_keeps_each_gyms_disposition_apart(tmp_path):
    root = registry(tmp_path, source(gyms=SHARED))
    first_run(root)
    rgp(root, "w2", "src", WEEK2)
    ref = reg.ingest(root, "w2", "src", "test")["findings"][0]
    assert all(held(root, gym, "w2")[ref]["status"] == "pending" for gym in SHARED)
    assert reg.close(root, "w2")[0]["src"]["advanced"] == "baseline"

    reg.review(root, ["Gym A"], "wren", "drafting the new Thursday", outcome="held", run="w2")
    reg.review(root, ["Gym B"], "sage", "not our programme", outcome="no-change", run="w2")
    reg.review(root, [], "linden", "nothing for the rest", outcome="no-change", run="w2",
               all_gyms=True)
    status = {gym: held(root, gym)[ref] for gym in SHARED}
    assert status["Gym A"]["status"] == "pending"            # held stays open
    assert status["Gym A"]["dispositions"][0]["note"] == "drafting the new Thursday"
    assert len(status["Gym A"]["dispositions"]) == 1         # --all-gyms did not override it
    assert status["Gym B"]["status"] == "resolved"
    assert status["Gym C"]["status"] == "resolved"
    assert [f["gym"] for f in reg.open_findings(root) if f["run"] == "w2"] == ["Gym A"]


def test_a_review_is_bound_to_the_capture_it_saw(tmp_path):
    root = registry(tmp_path, source())
    first_run(root)
    rgp(root, "w2", "src", WEEK2)
    first = reg.ingest(root, "w2", "src", "test")["findings"][0]
    later = rgp(root, "w2", "src", WEEK2 + ["Thu, December 17, 6 PM to 7 PM"])  # recaptured
    assert later.name == "1" and later.parent.name == "attempts"
    second = reg.ingest(root, "w2", "src", "test")["findings"][0]
    assert first != second

    done = reg.review(root, ["Gym A"], "wren", "added both Thursdays", outcome="proposed",
                      run="w2")
    assert [row["ref"] for row in done] == [second]
    assert held(root, "Gym A")[first]["status"] == "pending"
    assert (root / held(root, "Gym A")[first]["capture"]).exists()  # never moved
    reg.review(root, ["Gym A"], "wren", "covered by the same proposal", outcome="proposed",
               refs=[first])
    assert [f for f in reg.open_findings(root) if f["run"] == "w2"] == []


def test_close_saves_a_finding_again_if_an_edit_dropped_it(tmp_path):
    root = registry(tmp_path, source())
    first_run(root)
    rgp(root, "w2", "src", WEEK2)
    ref = reg.ingest(root, "w2", "src", "test")["findings"][0]
    path = reg.decisions_path(root, "w2", "Gym A")
    path.write_text(json.dumps([{"ref": "collector-note", "status": "pending"}]))  # overwritten
    assert reg.close(root, "w2")[0]["src"]["findings"] == [ref]
    assert {r["ref"] for r in json.loads(path.read_text())} == {"collector-note", ref}
    reg.close(root, "w2")  # closing again saves nothing twice
    assert len(json.loads(path.read_text())) == 2


# --------------------------------------------------------------- what never moves one

def test_a_failed_capture_keeps_the_baseline_and_records_the_attempt(tmp_path):
    root = registry(tmp_path, source())
    before = first_run(root)
    folder = reg.new_attempt_folder(root, "w2", "src")
    (folder / "src.rgp.json").write_text(json.dumps(
        {"id": "src", "url": RGP, "captured_at": "2026-11-17T10:00:00+00:00",
         "months": [], "series": []}))
    out = reg.ingest(root, "w2", "src", "test")
    assert out["outcome"] == "failed" and out["verdict"]["status"] == "incomplete"
    assert out["findings"] == []
    results, _, gaps = reg.close(root, "w2")
    assert results["src"]["advanced"] is None and entry(root)["baseline"] == before
    assert entry(root)["last_attempt"]["outcome"] == "failed"
    assert [gap["source_id"] for gap in gaps] == ["src"]


def test_incomplete_coverage_never_advances_even_when_the_comparison_is_unchanged(tmp_path):
    root = registry(tmp_path, source())
    rgp(root, "w1", "src", [], captured_at="2026-11-10T10:00:00+00:00")
    reg.ingest(root, "w1", "src", "test")
    assert reg.close(root, "w1")[0]["src"]["advanced"] == "baseline"
    before = entry(root)["baseline"]

    rgp(root, "w2", "src", [], read=1)  # one of three months
    out = reg.ingest(root, "w2", "src", "test")
    assert not out["eligible"] and "coverage incomplete" in out["blocked"]
    assert reg.close(root, "w2")[0]["src"]["advanced"] is None
    assert entry(root)["baseline"] == before

    record = {"outcome": "read-empty", "coverage": {"complete": False}}
    slot, reason = reg.decide(source(), record, {"status": "unchanged"})
    assert slot is None and "coverage incomplete" in reason


def test_a_reconstructed_social_summary_is_never_eligible():
    record = {"outcome": "read", "coverage": {"complete": True, "recovered": True}}
    assert not reg.eligible(record, "instagram")
    assert reg.eligible(record, "rockgympro")


def test_a_notice_is_saved_as_a_finding_and_does_not_move_the_baseline(tmp_path):
    root = registry(tmp_path, source(url="https://gym.test/programs", kind="web page"))
    page(reg.source_dir(root, "w1", "src"), "src", PAGE)
    reg.ingest(root, "w1", "src", "test")
    assert reg.close(root, "w1")[0]["src"]["advanced"] == "baseline"

    page(reg.source_dir(root, "w2", "src"), "src", "This plan is inactive.\n" + PAGE)
    out = reg.ingest(root, "w2", "src", "test")
    assert reg.close(root, "w2")[0]["src"]["advanced"] is None
    assert entry(root)["baseline"]["run"] == "w1"
    notice = held(root, "Gym A", "w2")[out["findings"][0]]
    assert notice["kind"] == "source_notice" and "plan-inactive" in notice["summary"]
    assert notice["evidence"] == ["runs/w1/sources/src/src.meta.json",
                                  "runs/w2/sources/src/src.meta.json"]


# ----------------------------------------------------- page and calendar kept apart

def test_a_page_only_read_moves_the_page_baseline_and_keeps_the_calendar(tmp_path):
    root = registry(tmp_path, source())
    calendar = first_run(root)
    rgp_page_only(root, "w2", "src")
    out = reg.ingest(root, "w2", "src", "test")
    assert out["baseline"]["slot"] == "page_baseline" and out["calendar_observed"] is False
    news = held(root, "Gym A", "w2")[out["findings"][0]]  # text the calendar read lacked
    assert news["summary"].startswith("Calendar not shown this run, and the offering page has")
    assert news["evidence"] == [calendar["capture"], out["capture"]]
    results, _, gaps = reg.close(root, "w2")
    assert results["src"]["advanced"] == "page_baseline"
    record = entry(root)
    assert record["baseline"] == calendar                     # calendar evidence kept
    assert record["page_baseline"]["run"] == "w2"
    assert record["calendar_gap"] == {"since_run": "w2", "last_run": "w2",
                                      "reason": "calendar markup not observed; page text read"}
    assert [gap["source_id"] for gap in gaps] == ["src"]

    rgp_page_only(root, "w3", "src", OFFERING.replace("all levels", "beginners"))
    out = reg.ingest(root, "w3", "src", "test")
    assert out["verdict"]["status"] == "changed"
    finding = held(root, "Gym A", "w3")[out["findings"][0]]
    assert finding["summary"].startswith("Page content changed; interpretation pending.")
    assert finding["details"]["lines_added"] == [
        "Weekly coached sessions for climbers aged 12 to 17, beginners welcome."]
    assert "added" not in finding["details"]  # a page change never claims sessions
    reg.close(root, "w3")
    assert entry(root)["calendar_gap"]["since_run"] == "w2"  # still open since w2

    rgp(root, "w4", "src", WEEK2)  # the calendar is back: compared with w1's calendar
    out = reg.ingest(root, "w4", "src", "test")
    assert out["baseline"]["capture"] == calendar["capture"]
    assert out["verdict"]["status"] == "changed"
    reg.close(root, "w4")
    record = entry(root)
    assert record["calendar_gap"] is None and record["baseline"]["run"] == "w4"
    assert record["page_baseline"]["run"] == "w3"


def test_a_calendar_seen_for_the_first_time_after_page_reads_is_a_first_read(tmp_path):
    root = registry(tmp_path, source())
    rgp_page_only(root, "w1", "src")
    reg.ingest(root, "w1", "src", "test")
    reg.close(root, "w1")
    assert entry(root)["baseline"] is None and entry(root)["page_baseline"]["run"] == "w1"

    rgp(root, "w2", "src", WEEK1)
    out = reg.ingest(root, "w2", "src", "test")
    assert out["verdict"]["status"] == "new-baseline"
    assert "First accepted read of this calendar" in held(root, "Gym A", "w2")[
        out["findings"][0]]["summary"]
    reg.close(root, "w2")
    assert entry(root)["baseline"]["run"] == "w2" and entry(root)["calendar_gap"] is None


# ------------------------------------------------------------------------------ socials

def test_structured_instagram_captures_compare_by_post_and_carry_an_anchor(tmp_path):
    root = registry(tmp_path, source(url="https://www.instagram.com/gymhandle/",
                                     kind="instagram"))
    ig(root, "w1", "src", ["DfnKjHABuJI", "DeW8JHxI7ud"])
    assert reg.ingest(root, "w1", "src", "test")["eligible"]
    reg.close(root, "w1")
    assert entry(root)["baseline"]["anchor"] == "DfnKjHABuJI"

    ig(root, "w2", "src", ["DgNEWPOST01", "DfnKjHABuJI"], anchor="DfnKjHABuJI")
    out = reg.ingest(root, "w2", "src", "test")
    assert out["verdict"]["status"] == "changed"
    finding = held(root, "Gym A", "w2")[out["findings"][0]]
    assert finding["summary"] == "Feed changed: 1 new post(s): DgNEWPOST01 (2026-11-20)."
    assert finding["details"]["added_posts"][0]["url"] == \
        "https://www.instagram.com/p/DgNEWPOST01/"
    assert reg.close(root, "w2")[0]["src"]["advanced"] == "baseline"


def test_a_social_capture_that_misses_its_anchor_keeps_the_baseline(tmp_path):
    root = registry(tmp_path, source(url="https://www.instagram.com/gymhandle/",
                                     kind="instagram"))
    ig(root, "w1", "src", ["DfnKjHABuJI", "DeW8JHxI7ud"])
    reg.ingest(root, "w1", "src", "test")
    reg.close(root, "w1")
    before = entry(root)["baseline"]

    ig(root, "w2", "src", ["DgNEWPOST01", "DgNEWPOST02"], anchor="DfnKjHABuJI")
    out = reg.ingest(root, "w2", "src", "test")
    assert out["verdict"]["status"] == "incomplete" and not out["eligible"]
    assert reg.close(root, "w2")[0]["src"]["advanced"] is None
    assert entry(root)["baseline"] == before


def test_what_a_partial_capture_saw_is_saved_as_provisional():
    """An incomplete verdict that still reports additions becomes a provisional finding."""
    wrapper = {"capture": "runs/w2/sources/src/src.ig.json", "capture_sha256": "c" * 64,
               "baseline": {"slot": "baseline", "capture": "runs/w1/sources/src/src.ig.json",
                            "sha256": "b" * 64}, "eligible": False}
    verdict = {"status": "incomplete", "coverage": {"reason": "anchor-not-reached"},
               "changes": {"added_posts": [{"id": "DgNEWPOST01", "kind": "post",
                                            "published": "2026-11-20"}]}}
    record = {"type": "instagram", "outcome": "partial", "posts": [
        {"id": "DgNEWPOST01", "url": "https://www.instagram.com/p/DgNEWPOST01/"}]}
    insta = source(url="https://www.instagram.com/gymhandle/", kind="instagram")
    [template] = reg.finding_templates(None, insta, wrapper, record, verdict)
    assert template["kind"] == "source_change" and template["provisional"]
    assert template["summary"] == ("Partial capture (anchor-not-reached), so no baseline moved. "
                                   "Provisionally: Feed changed: 1 new post(s): DgNEWPOST01 "
                                   "(2026-11-20).")


# --------------------------------------------------------------------------- the lock

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
        source("offer", url="https://app.rockgympro.com/b/?bo=offer"),
        source("index", url="https://app.rockgympro.com/b/?bw=index"),
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
    for name in ("offer", "index"):
        (evidence / (name + ".rgp.json")).write_text(json.dumps(
            {"id": name, "url": "https://app.rockgympro.com/b/?%s=%s" % (
                "bo" if name == "offer" else "bw", name),
             "captured_at": "2026-11-12T14:00:00+00:00", "months": [], "series": []}))
        (evidence / (name + ".rgp.txt")).write_text(OFFERING)
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
    assert by_id["cal"]["baseline"]["recovered"] is True and by_id["cal"]["calendar_gap"] is None
    assert by_id["offer"]["baseline"] is None
    assert by_id["offer"]["page_baseline"]["evidence"] == "page-only"
    assert by_id["offer"]["calendar_gap"]["reason"] == "calendar markup not observed; page text read"
    assert by_id["index"]["system"] == "page" and by_id["index"]["baseline"] is None
    assert {"id": "index", "system": "page",
            "reason": "discovery page captured as rockgympro; capture it as a page"} in \
        report["no_baseline"]
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
        assert not {"last_copy", "fingerprint", "last_checked"} & set(record)
    assert reg.load(root)[0]["last_copy"] == old + "cal.rgp.json"  # nothing written
