"""What changed? One test per comparison rule, plus the failures the repair exists for.

Every case is a pair of capture records built by hand, so the rule under test is the
only thing in play. `test_corpus.py` replays the real November captures afterwards.
"""
import compare


def entry(date, start=None, end=None, state="available", cohort=None, line=None):
    return {"date": date, "start": start, "end": end, "state": state, "cohort": cohort,
            "line": line or "%s %s to %s" % (date, start, end)}


def calendar(entries, months=None, captured_at="2026-11-17T09:00:00+00:00",
             outcome="read", evidence=None, errors=None):
    return {"source_id": "src", "type": "rockgympro", "captured_at": captured_at,
            "outcome": outcome, "evidence": evidence,
            "window": {"months": months if months is not None
                       else sorted({e["date"][:7] for e in entries if e.get("date")}),
                       "read": 3},
            "entries": entries, "errors": errors or [], "notes": []}


def page(text_sha, captured_at="2026-11-17T09:00:00+00:00", outcome="read"):
    return {"source_id": "src", "type": "page", "captured_at": captured_at,
            "outcome": outcome, "window": {"months": [], "read": 0},
            "entries": [{"text_sha": text_sha}], "notes": []}


def social(posts, captured_at="2026-11-17T09:00:00+00:00", outcome="read"):
    return {"source_id": "src", "type": "instagram", "captured_at": captured_at,
            "outcome": outcome, "window": {"months": [], "read": 0}, "entries": [],
            "posts": posts, "notes": []}


def post(ident, sha="a", published=None):
    return {"id": ident, "kind": "post", "published": published, "text_sha": sha,
            "alts_sha": None}


# ------------------------------------------------------------------------------ calendars

def test_a_new_date_under_clicks_is_a_change():
    before = calendar([entry("2026-11-13", "18:30", "19:30")])
    after = calendar([entry("2026-11-13", "18:30", "19:30"),
                      entry("2026-11-20", "18:30", "19:30")])
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "changed"
    assert [a["date"] for a in verdict["changes"]["added"]] == ["2026-11-20"]


def test_identical_content_is_unchanged_even_when_captured_at_differs():
    before = calendar([entry("2026-11-20", "18:30", "19:30")],
                      captured_at="2026-11-10T09:00:00+00:00")
    after = calendar([entry("2026-11-20", "18:30", "19:30")])
    assert compare.compare_source(before, after)["status"] == "unchanged"


def test_an_elapsed_date_leaving_is_suppressed_not_removed():
    before = calendar([entry("2026-11-10", "18:30", "19:30"),
                       entry("2026-11-24", "18:30", "19:30")])
    after = calendar([entry("2026-11-24", "18:30", "19:30")])
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "unchanged"
    assert verdict["changes"]["removed"] == []
    assert {"what": "2026-11-10", "reason": "elapsed"} in verdict["suppressed"]


def test_a_sliding_window_alone_is_not_a_change():
    before = calendar([entry("2026-12-03", "18:00", "19:00")],
                      months=["2026-11", "2026-12", "2027-01"])
    after = calendar([entry("2026-12-03", "18:00", "19:00")],
                     months=["2026-12", "2027-01", "2027-02"])
    assert compare.compare_source(before, after)["status"] == "unchanged"


def test_an_aged_baseline_does_not_manufacture_a_removal():
    before = calendar([entry("2026-11-19", "18:00", "19:00")],
                      captured_at="2026-11-10T09:00:00+00:00",
                      months=["2026-11", "2026-12", "2027-01"])
    after = calendar([entry("2026-11-19", "18:00", "19:00")])
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "unchanged"
    assert verdict["changes"]["removed"] == []


def test_the_same_date_in_different_years_is_a_change():
    before = calendar([entry("2026-01-14", "16:30", "18:30")],
                      captured_at="2025-12-01T09:00:00+00:00",
                      months=["2026-01", "2027-01"])
    after = calendar([entry("2027-01-14", "16:30", "18:30")],
                     captured_at="2025-12-01T09:00:00+00:00",
                     months=["2026-01", "2027-01"])
    assert compare.compare_source(before, after)["status"] == "changed"


def test_an_unresolved_year_cannot_produce_a_removal():
    before = calendar([entry(None, "16:30", "18:30")], months=["2026-12", "2027-12"])
    after = calendar([entry(None, "16:30", "18:30")], months=["2026-12", "2027-12"])
    verdict = compare.compare_source(before, after)
    assert verdict["changes"]["removed"] == []
    assert verdict["status"] == "unchanged"


def test_a_renumbered_course_label_is_not_a_change():
    before = calendar([{**entry("2027-01-07", "18:00", "19:00"),
                        "line": "Thu, Jan 7, 6 PM to 7 PM", "raw": "Day #1: Thu, Jan 7, 6 PM to 7 PM"}])
    after = calendar([{**entry("2027-01-07", "18:00", "19:00"),
                       "line": "Thu, Jan 7, 6 PM to 7 PM", "raw": "Day #8: Thu, Jan 7, 6 PM to 7 PM"}])
    assert compare.compare_source(before, after)["status"] == "unchanged"


def test_a_single_slot_moving_time_is_one_move():
    before = calendar([entry("2026-11-20", "18:30", "19:30")])
    after = calendar([entry("2026-11-20", "19:00", "20:00")])
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "changed"
    assert len(verdict["changes"]["moved"]) == 1
    assert verdict["changes"]["added"] == [] and verdict["changes"]["removed"] == []


def test_two_slots_on_one_date_are_not_paired_into_a_move():
    before = calendar([entry("2026-11-20", "10:00", "11:00"),
                       entry("2026-11-20", "18:00", "19:00")])
    after = calendar([entry("2026-11-20", "10:00", "11:00"),
                      entry("2026-11-20", "19:00", "20:00")])
    verdict = compare.compare_source(before, after)
    assert verdict["changes"]["moved"] == []
    assert verdict["changes"]["added"] and verdict["changes"]["removed"]
    assert all(e["ambiguous_pairing"] for e in
               verdict["changes"]["added"] + verdict["changes"]["removed"])


def test_availability_change_is_its_own_channel():
    before = calendar([entry("2026-11-23", state="available")])
    after = calendar([entry("2026-11-23", state="full")])
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "unchanged"
    assert verdict["availability_changes"] == [
        {"date": "2026-11-23", "start": None, "end": None,
         "from": "available", "to": "full"}]


def test_two_verified_empty_calendars_are_unchanged():
    before = calendar([], outcome="read-empty", evidence="zero-available-days")
    after = calendar([], outcome="read-empty", evidence="zero-available-days")
    assert compare.compare_source(before, after)["status"] == "unchanged"


def test_a_verified_empty_against_a_failure_is_incomplete():
    before = calendar([], outcome="read-empty", evidence="zero-available-days")
    after = calendar([], outcome="failed")
    verdict = compare.compare_source(before, after)
    assert verdict["status"] == "incomplete"
    assert verdict["coverage"]["met"] is False


def test_two_failures_are_never_unchanged():
    before = calendar([], outcome="failed")
    after = calendar([], outcome="failed")
    assert compare.compare_source(before, after)["status"] == "incomplete"


def test_a_changed_error_message_is_not_a_session_change():
    before = calendar([], outcome="read", evidence="clicked-no-times",
                      errors=[{"reason": "no-available-times", "clicked_date": "12"}])
    after = calendar([], outcome="read", evidence="clicked-no-times",
                     errors=[{"reason": "no-available-times", "clicked_date": "19"}])
    assert compare.compare_source(before, after)["status"] == "unchanged"


def test_no_baseline_sets_one_without_claiming_a_change():
    verdict = compare.compare_source(None, calendar([entry("2026-11-20")]))
    assert verdict["status"] == "new-baseline"
    assert verdict["changes"]["added"] == []


# ----------------------------------------------------------------------------------- page

def test_identical_page_text_is_unchanged():
    assert compare.compare_source(page("a"), page("a"))["status"] == "unchanged"


def test_changed_page_text_is_a_change():
    verdict = compare.compare_source(page("a"), page("b"))
    assert verdict["status"] == "changed"
    assert verdict["changes"]["edited"][0]["field"] == "text_sha"


# --------------------------------------------------------------------------------- social

def test_a_new_post_is_an_addition():
    verdict = compare.compare_source(social([post("A"), post("C")]),
                                     social([post("B"), post("A"), post("C")]))
    assert verdict["status"] == "changed"
    assert [p["id"] for p in verdict["changes"]["added_posts"]] == ["B"]


def test_an_edited_post_keeps_its_identity():
    verdict = compare.compare_source(social([post("A", sha="old")]),
                                     social([post("A", sha="new")]))
    assert verdict["status"] == "changed"
    assert [p["id"] for p in verdict["changes"]["edited_posts"]] == ["A"]


def test_a_post_missing_from_the_feed_is_not_seen_not_deleted():
    verdict = compare.compare_source(social([post("A"), post("B")]),
                                     social([post("A")]))
    assert verdict["changes"]["not_seen"][0]["id"] == "B"
    assert verdict["status"] == "unchanged"


def test_a_feed_that_stops_before_the_baseline_post_is_incomplete():
    verdict = compare.compare_source(social([post("A"), post("B")]),
                                     social([post("C")]))
    assert verdict["status"] == "incomplete"
    assert verdict["coverage"]["reason"] == "anchor-not-reached"


def test_two_empty_social_captures_are_incomplete():
    verdict = compare.compare_source(social([], outcome="failed"),
                                     social([], outcome="failed"))
    assert verdict["status"] == "incomplete"


def test_posts_without_ids_are_reported_not_compared():
    verdict = compare.compare_source(social([post("A")]),
                                     social([post("A"), {"id": None, "text_sha": "x"}]))
    assert any("no stable id" in note for note in verdict["notes"])
