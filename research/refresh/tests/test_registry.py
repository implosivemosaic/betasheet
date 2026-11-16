"""Where baselines live, when they move, and how unresolved changes survive: end to end.

Each case writes a small registry and real capture files, then runs the functions the
commands use: ingest (extract + compare + save findings), review, close. Fixtures are
synthetic, shaped like the capture tools' output.
"""
import contextlib
import io
import json
import subprocess
import sys

import coverage
import recover as rec
import refresh
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


def rgp_legacy(root, run, sid, days, clicks=None, captured_at="2026-11-12T14:00:00+00:00"):
    """A Rock Gym Pro capture as the November tool wrote it: no declared coverage, and one
    session recorded per highlighted date. `clicks` are day lines from clicked dates."""
    folder = reg.new_attempt_folder(root, run, sid)
    months = [{"title": title, "available": []} for title in MONTHS]
    if clicks:
        months[0].update(available=["26"], clicks=[{"days": list(clicks)}])
    (folder / (sid + ".rgp.json")).write_text(json.dumps(
        {"id": sid, "url": RGP, "captured_at": captured_at, "months": months,
         "series": [{"date_selected": "Date Selected: " + ", ".join(days[0].split(", ")[:2]),
                     "days": list(days)}] if days else []}))
    (folder / (sid + ".rgp.txt")).write_text(GRID)
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


def proposal_entry(root, run, folder, ref, path=None):
    """A proposal as a collector writes it in gyms/<gym>/proposals.json (bare ref), or as the
    coordinator writes it in another of the run's proposal files (path, prefixed ref)."""
    target = root / (path or "runs/%s/gyms/%s/proposals.json" % (run, folder))
    entries = json.loads(target.read_text()) if target.exists() else []
    entries.append({"ref": ref, "approved": False, "review": "publish", "action": "update",
                    "id": 104, "gym": "Gym A", "why": "test", "attrs": {}, "evidence": [],
                    "sessions": None})
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(entries))


def receipt(root, path, ref, target, listing_id=104):
    """A row research/apply_record.py appends to a package's applied.json."""
    file = root / path
    rows = json.loads(file.read_text()) if file.exists() else []
    rows.append({"id": listing_id, "ref": ref, "sessions": 3, "status": "ok",
                 "title": "Thursday", "target": target})
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps(rows))


def changed(tmp_path, gyms=("Gym A",)):
    """A source cited by `gyms` whose week-2 capture added a Thursday: (root, finding ref)."""
    root = registry(tmp_path, source(gyms=gyms))
    first_run(root)
    rgp(root, "w2", "src", WEEK2)
    ref = reg.ingest(root, "w2", "src", "test")["findings"][0]
    reg.close(root, "w2")
    return root, ref


def cli(*args):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        code = refresh.main(list(args))
    return code, out.getvalue(), err.getvalue()


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

    proposal_entry(root, "w2", "gym-a", "both-thursdays")
    done = reg.review(root, ["Gym A"], "wren", "added both Thursdays", outcome="proposed",
                      run="w2", proposal="both-thursdays")
    assert [row["ref"] for row in done] == [second]
    assert held(root, "Gym A")[first]["status"] == "pending"
    assert (root / held(root, "Gym A")[first]["capture"]).exists()  # never moved
    reg.review(root, ["Gym A"], "wren", "covered by the same proposal", outcome="proposed",
               refs=[first], proposal="both-thursdays")
    assert {f["ref"]: f["status"] for f in reg.open_findings(root) if f["run"] == "w2"} == \
        {first: "proposed", second: "proposed"}


# ------------------------------------------- a proposed finding waits on its proposal

def test_proposed_needs_a_proposal_that_exists(tmp_path):
    root, ref = changed(tmp_path, gyms=("Gym A", "Gym B"))

    def refused(gyms=("Gym A",), **kwargs):
        try:
            reg.review(root, list(gyms), "wren", "drafted", run="w2", **kwargs)
        except reg.RegistryError as exc:
            return str(exc)
        raise AssertionError("review accepted %r" % kwargs)

    assert "needs --proposal" in refused(outcome="proposed")
    assert "no proposal gym-a/thursday-added" in refused(outcome="proposed",
                                                         proposal="thursday-added")
    proposal_entry(root, "w2", "gym-a", "thursday-added")
    assert "no proposal gym-b/thursday-added" in refused(outcome="proposed",
                                                         proposal="gym-b/thursday-added")
    assert "<gym-folder>/<ref>" in refused(gyms=("Gym A", "Gym B"), outcome="proposed",
                                           proposal="thursday-added")
    assert "<gym-folder>/<ref>" in refused(outcome="proposed", proposal="../gym-a/x")
    assert "--outcome proposed only" in refused(outcome="no-change",
                                                proposal="gym-a/thursday-added")
    assert all(held(root, gym, "w2")[ref]["status"] == "pending" for gym in ("Gym A", "Gym B"))

    # A proposal is looked up in one run, and a coordinator's prefixed proposal file counts.
    proposal_entry(root, "w3", "gym-a", "thursday-added")
    assert reg.find_proposal(root, "gym-a/thursday-added", "w3") == {
        "ref": "gym-a/thursday-added", "run": "w3", "file": "runs/w3/gyms/gym-a/proposals.json"}
    assert reg.find_proposal(root, "gym-a/thursday-added", "w1") is None
    proposal_entry(root, "w2", None, "gym-b/coach-swap",
                   path="runs/w2/consolidated/additional-proposals.json")
    assert reg.find_proposal(root, "gym-b/coach-swap", "w2") == {
        "ref": "gym-b/coach-swap", "run": "w2",
        "file": "runs/w2/consolidated/additional-proposals.json"}


def test_a_proposed_finding_stays_open_and_linked_until_a_receipt_shows_it_published(tmp_path):
    root, ref = changed(tmp_path, gyms=("Gym A", "Gym B"))
    proposal_entry(root, "w2", "gym-a", "thursday-added")
    link = {"ref": "gym-a/thursday-added", "run": "w2", "file": "runs/w2/gyms/gym-a/proposals.json"}
    done = reg.review(root, ["Gym A"], "wren", "drafted the new Thursday", outcome="proposed",
                      run="w2", proposal="thursday-added")
    assert done == [{"gym": "Gym A", "ref": ref, "status": "proposed", "proposal": link}]
    reg.review(root, ["Gym B"], "sage", "same Thursday, proposed under Gym A",
               outcome="proposed", run="w2", proposal="gym-a/thursday-added")

    reg.review(root, [], "linden", "nothing else", outcome="no-change", run="w2", all_gyms=True)
    reg.review(root, ["Gym A"], "linden", "nothing here", outcome="no-change", run="w2")
    found = {f["gym"]: f for f in reg.open_findings(root) if f["ref"] == ref}
    assert set(found) == {"Gym A", "Gym B"}  # neither blanket review touched a proposed record
    assert found["Gym A"]["status"] == "proposed" and found["Gym A"]["proposal"] == link
    assert found["Gym A"]["dispositions"][-1]["proposal"] == link
    assert found["Gym B"]["proposal"] == link
    assert found["Gym A"]["proposal_state"] == {"state": "awaiting publication"}
    reg.close(root, "w2")
    close = reg.read_json(reg.run_dir(root, "w2") / "close.json")
    assert {(f["gym"], f["proposal"]["ref"]) for f in close["pending_findings"]
            if f["ref"] == ref} == {("Gym A", link["ref"]), ("Gym B", link["ref"])}

    receipt(root, "runs/w2/validation/applied.json", link["ref"], target="dev")
    assert len([f for f in reg.open_findings(root) if f["ref"] == ref]) == 2
    receipt(root, "runs/w2/publication/applied.json", link["ref"], target="prod")
    assert [f for f in reg.open_findings(root) if f["ref"] == ref] == []
    done = {f["gym"]: f for f in reg.open_findings(root, include_resolved=True)
            if f["ref"] == ref}
    assert done["Gym A"]["status"] == "resolved"
    assert done["Gym A"]["proposal_state"] == {"state": "published", "listing_id": 104,
                                               "receipt": "runs/w2/publication/applied.json"}


def test_a_receipt_counts_only_for_the_linked_proposals_own_run(tmp_path):
    """Refs are reused across seasons: another run's `winter-camp` is different work."""
    root, ref = changed(tmp_path)
    proposal_entry(root, "w2", "gym-a", "winter-camp")
    reg.review(root, ["Gym A"], "wren", "drafted the 2027 camp", outcome="proposed", run="w2",
               proposal="winter-camp")

    def state():
        [finding] = [f for f in reg.open_findings(root, include_resolved=True)
                     if f["ref"] == ref]
        return finding["status"], finding["proposal_state"]

    receipt(root, "runs/w1/publication/applied.json", "gym-a/winter-camp", "prod", 311)
    receipt(root, "runs/w3/publication/applied.json", "gym-a/winter-camp", "prod", 777)
    receipt(root, "runs/w2/publication/applied.json", "gym-b/winter-camp", "prod", 402)
    receipt(root, "runs/w2/publication/applied.json", "winter-camp", "prod", 403)
    status, proposal_state = state()
    assert status == "proposed" and proposal_state["state"] == "awaiting publication"
    assert proposal_state["same_ref_other_runs"] == ["runs/w1/publication/applied.json",
                                                     "runs/w3/publication/applied.json"]

    receipt(root, "runs/w2/publication/applied.json", "gym-a/winter-camp", "prod", 512)
    assert state() == ("resolved", {"state": "published", "listing_id": 512,
                                    "receipt": "runs/w2/publication/applied.json"})


def test_a_proposal_is_linked_in_the_findings_run_unless_a_later_run_is_named(tmp_path):
    root, ref = changed(tmp_path)  # the finding is from w2
    proposal_entry(root, "w1", "gym-a", "thursday-added")  # an older proposal, same ref

    def refused(**kwargs):
        try:
            reg.review(root, ["Gym A"], "wren", "drafted", outcome="proposed", **kwargs)
        except reg.RegistryError as exc:
            return str(exc)
        raise AssertionError("review accepted %r" % kwargs)

    assert "no proposal gym-a/thursday-added in run w2" in refused(
        run="w2", proposal="thursday-added")
    assert "run w1 is before the finding's run w2" in refused(
        refs=[ref], proposal="thursday-added", proposal_run="w1")
    assert "no run '../w2' under runs/" in refused(refs=[ref], proposal="thursday-added",
                                                   proposal_run="../w2")
    assert held(root, "Gym A", "w2")[ref]["status"] == "pending"

    # Held in w2 and carried into w3: the link stays on w2's proposal until it is relinked.
    proposal_entry(root, "w2", "gym-a", "thursday-added")
    reg.review(root, ["Gym A"], "wren", "drafted", outcome="proposed", run="w2",
               proposal="thursday-added")
    proposal_entry(root, "w3", "gym-a", "thursday-added")
    receipt(root, "runs/w3/publication/applied.json", "gym-a/thursday-added", "prod", 640)
    [finding] = [f for f in reg.open_findings(root) if f["ref"] == ref]
    assert finding["proposal"]["run"] == "w2"
    assert finding["proposal_state"]["same_ref_other_runs"] == ["runs/w3/publication/applied.json"]
    done = reg.review(root, ["Gym A"], "dot", "carried into w3", outcome="proposed", refs=[ref],
                      proposal="thursday-added", proposal_run="w3")
    assert done[0]["proposal"] == {"ref": "gym-a/thursday-added", "run": "w3",
                                   "file": "runs/w3/gyms/gym-a/proposals.json"}
    assert [f for f in reg.open_findings(root) if f["ref"] == ref] == []


def test_findings_from_several_runs_need_the_proposal_run_named(tmp_path):
    root, first = changed(tmp_path)
    rgp(root, "w3", "src", WEEK2 + ["Thu, December 17, 6 PM to 7 PM"])
    second = reg.ingest(root, "w3", "src", "test")["findings"][0]
    proposal_entry(root, "w3", "gym-a", "thursdays")
    try:
        reg.review(root, ["Gym A"], "wren", "both", outcome="proposed", refs=[first, second],
                   proposal="thursdays")
        raise AssertionError("review accepted findings from two runs without --proposal-run")
    except reg.RegistryError as exc:
        assert "come from runs w2, w3" in str(exc)
    done = reg.review(root, ["Gym A"], "wren", "both", outcome="proposed", refs=[first, second],
                      proposal="thursdays", proposal_run="w3")
    assert sorted(row["ref"] for row in done) == sorted([first, second])


def test_a_withdrawn_proposal_is_settled_by_disposing_the_finding_again(tmp_path):
    root, ref = changed(tmp_path)
    proposal_entry(root, "w2", "gym-a", "thursday-added")
    reg.review(root, ["Gym A"], "wren", "drafted", outcome="proposed", run="w2",
               proposal="thursday-added")
    reg.review(root, ["Gym A"], "dot", "withdrawn: the gym cancelled the Thursday",
               outcome="no-change", refs=[ref])
    record = held(root, "Gym A", "w2")[ref]
    assert record["status"] == "resolved" and "proposal" not in record
    assert [d["outcome"] for d in record["dispositions"]] == ["proposed", "no-change"]
    assert record["dispositions"][0]["proposal"]["ref"] == "gym-a/thursday-added"


def test_the_findings_command_shows_the_proposal_a_finding_waits_on(tmp_path):
    root, ref = changed(tmp_path)
    data = ("--data", str(root))
    review = ("review", "--gym", "Gym A", "--run", "w2", "--outcome", "proposed",
              "--by", "wren", "--note", "drafted")
    code, _, err = cli(*data, *review)
    assert code == 1 and "needs --proposal" in err
    code, _, err = cli(*data, *review, "--proposal", "thursday-added")
    assert code == 1 and "no proposal gym-a/thursday-added" in err

    proposal_entry(root, "w2", "gym-a", "thursday-added")
    code, out, _ = cli(*data, *review, "--proposal", "thursday-added")
    assert code == 0 and "%s  Gym A: proposed -> gym-a/thursday-added (run w2)" % ref in out
    code, out, _ = cli(*data, "findings", "--gym", "Gym A")
    assert code == 0
    assert ("  proposal: gym-a/thursday-added in runs/w2/gyms/gym-a/proposals.json, "
            "awaiting publication") in out
    assert out.strip().endswith("%d finding(s) unresolved"
                                % len(reg.open_findings(root, gym="Gym A")))


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
    assert not out["eligible"] and "read 1 of 3 requested months" in out["blocked"]
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
    assert out["verdict"]["status"] == "new-baseline"
    assert out["findings"] == []  # the first page read sets the page baseline; nothing to compare
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


def test_a_live_page_only_capture_sets_the_page_baseline(tmp_path):
    """The shape tools/rgp.py writes when no calendar panel rendered: a web-page block."""
    root = registry(tmp_path, source())
    calendar = first_run(root)
    folder = reg.new_attempt_folder(root, "w2", "src")
    (folder / "src.rgp.json").write_text(json.dumps(
        {"id": "src", "url": RGP, "captured_at": "2026-11-17T10:00:00+00:00", "months": [],
         "series": [], "notes": [], "coverage": coverage.page(len(OFFERING.splitlines()))}))
    (folder / "src.rgp.txt").write_text(OFFERING)
    out = reg.ingest(root, "w2", "src", "test")
    assert (out["outcome"], out["evidence"], out["eligible"]) == ("read", "page-only", True)
    assert out["findings"] == []
    assert reg.close(root, "w2")[0]["src"]["advanced"] == "page_baseline"
    assert entry(root)["baseline"] == calendar and entry(root)["calendar_gap"]["since_run"] == "w2"


def test_a_legacy_calendar_compares_by_date_and_lists_its_slots_to_reconcile(tmp_path):
    root = registry(tmp_path, source())
    rgp_legacy(root, "w1", "src", ["Thu, November 26, 6 PM to 7 PM",
                                   "Thu, December 3, 6 PM to 7 PM",
                                   "Thu, December 10, 6 PM to 7 PM"])
    reg.ingest(root, "w1", "src", "test")
    reg.close(root, "w1")
    assert entry(root)["baseline"]["slot_coverage"] == "dates-only"
    assert [q["source_id"] for q in reg.recapture_queue(reg.load(root))] == ["src"]
    assert reg.read_json(reg.run_dir(root, "w1") / "close.json")["recapture"][0]["source_id"] == "src"

    # Read in full: two more slots on 26 November, 10 December gone, 17 December new.
    rgp(root, "w2", "src", ["Thu, November 26, 4 PM to 5 PM", "Thu, November 26, 6 PM to 7 PM",
                            "Thu, November 26, 8 PM to 9 PM", "Thu, December 3, 6 PM to 7 PM",
                            "Thu, December 17, 6 PM to 7 PM"])
    out = reg.ingest(root, "w2", "src", "test")
    verdict = out["verdict"]
    assert verdict["status"] == "changed"
    assert [(e["date"], e["start"]) for e in verdict["changes"]["added"]] == [("2026-12-17", "18:00")]
    assert [(e["date"], e["start"]) for e in verdict["changes"]["removed"]] == [
        ("2026-12-10", "18:00")]
    assert [(e["date"], e["start"]) for e in verdict["slots_to_reconcile"]] == [
        ("2026-11-26", "16:00"), ("2026-11-26", "20:00")]
    found = {f["kind"]: f for f in (held(root, "Gym A", "w2")[r] for r in out["findings"])}
    assert found["source_change"]["summary"] == (
        "Calendar changed: 1 session(s) added: 2026-12-17 18:00-19:00; "
        "1 no longer listed: 2026-12-10 18:00-19:00.")
    assert found["source_first_read"]["summary"].startswith(
        "Time slots read in full for the first time: 2 session(s) on 1 date(s) from 2026-11-26")
    reg.close(root, "w2")
    assert "slot_coverage" not in entry(root)["baseline"]
    assert reg.recapture_queue(reg.load(root)) == []


def test_extra_slots_alone_leave_a_legacy_calendar_unchanged(tmp_path):
    root = registry(tmp_path, source())
    rgp_legacy(root, "w1", "src", ["Thu, November 26, 6 PM to 7 PM"])
    reg.ingest(root, "w1", "src", "test")
    reg.close(root, "w1")
    full = ["Thu, November 26, 6 PM to 7 PM", "Thu, November 26, 8 PM to 9 PM"]

    rgp(root, "w2", "src", full, read=2)  # partial: the slots are provisional, nothing moves
    out = reg.ingest(root, "w2", "src", "test")
    assert out["verdict"]["status"] == "incomplete" and out["verdict"]["provisional"]
    [finding] = [held(root, "Gym A", "w2")[r] for r in out["findings"]]
    assert finding["provisional"] and finding["summary"].startswith("Partial capture (")
    assert reg.close(root, "w2")[0]["src"]["advanced"] is None

    rgp(root, "w3", "src", full)
    out = reg.ingest(root, "w3", "src", "test")
    assert out["verdict"]["status"] == "unchanged"
    assert [held(root, "Gym A", "w3")[r]["kind"] for r in out["findings"]] == ["source_first_read"]
    assert reg.close(root, "w3")[0]["src"]["advanced"] == "baseline"


def test_clicked_days_with_no_times_need_declared_coverage_to_be_a_baseline(tmp_path):
    root = registry(tmp_path, source())
    rgp_legacy(root, "w1", "src", [],
               clicks=["Sorry, but there are no available times for Thu, November 26"])
    out = reg.ingest(root, "w1", "src", "test")
    assert out["evidence"] == "clicked-no-times" and not out["eligible"]
    assert "proves neither an empty calendar nor a complete read" in out["blocked"]
    results, _, gaps = reg.close(root, "w1")
    assert results["src"]["advanced"] is None and entry(root)["baseline"] is None
    assert [gap["source_id"] for gap in gaps] == ["src"]

    record = {"outcome": "read", "evidence": "clicked-no-times",
              "coverage": {"complete": True, "recovered": False}}
    assert reg.eligible(record, "rockgympro")  # declared, complete coverage is enough


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
        source("notice", url="https://gym.test/b", kind="web page"),
        dict(source("legacy", url="https://app.rockgympro.com/b/?bo=legacy"),
             last_copy=old + "rgpS-legacy-1.rgp.json"),
        source("notimes", url="https://app.rockgympro.com/b/?bo=notimes"))
    evidence.mkdir(parents=True)
    for name, url, series, clicks in (
            ("rgpS-legacy-1", "bo=legacy", ["Thu, November 26, 6 PM to 7 PM",
                                            "Thu, December 3, 6 PM to 7 PM"], None),
            ("notimes", "bo=notimes", [],
             ["Sorry, but there are no available times for Thu, November 26"])):
        months = [{"title": title, "available": []} for title in MONTHS]
        if clicks:
            months[0].update(available=["26"], clicks=[{"days": clicks}])
        (evidence / (name + ".rgp.json")).write_text(json.dumps(
            {"id": name, "url": "https://app.rockgympro.com/b/?" + url,
             "captured_at": "2026-11-12T14:00:00+00:00", "months": months,
             "series": [{"date_selected": "Date Selected: Thu, November 26", "days": series}]
             if series else []}))
        (evidence / (name + ".rgp.txt")).write_text(GRID)
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
    assert by_id["legacy"]["baseline"]["slot_coverage"] == "dates-only"
    assert report["recapture"] == [{"capture": old + "rgpS-legacy-1.rgp.json",
                                    "capture_id": "rgpS-legacy-1", "id": "legacy",
                                    "gyms": ["Gym A"], "sessions": 2}]
    assert "slot_coverage" not in by_id["cal"]["baseline"]  # an empty grid has no slots
    assert by_id["notimes"]["baseline"] is None
    assert "proves neither" in by_id["notimes"]["calendar_gap"]["reason"]
    assert sum(c["count"] for c in report["captures"]) == 9  # every capture file is counted
    assert report["accounted"] == {"files": 9, "accounted": 9}
    assert "legacy <- %srgpS-legacy-1.rgp.json (2 sessions; capture id rgpS-legacy-1)" % old \
        in rec.summary(report)
    for record in proposed:
        assert not {"last_copy", "fingerprint", "last_checked"} & set(record)
    assert reg.load(root)[0]["last_copy"] == old + "cal.rgp.json"  # nothing written
