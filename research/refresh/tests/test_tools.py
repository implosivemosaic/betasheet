"""The coverage block a capture writes: what it must state for a baseline to exist."""
import coverage


def test_calendar_coverage_records_the_populated_grid():
    months = [{"title": "November 2026", "cells_parsed": 35,
               "headers": ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]},
              {"title": "December 2026", "cells_parsed": 42, "headers": []}]
    block = coverage.calendar(3, months)
    assert block["months_read"] == 2 and block["months_requested"] == 3
    assert block["complete"] is False
    assert block["window"] == {"first": "November 2026", "last": "December 2026"}
    assert block["inspected"]["months"][0]["cells_parsed"] == 35
    assert block["inspected"]["months"][0]["headers"][0] == "Mo"


def test_page_coverage_separates_a_challenge_from_a_notice():
    challenge = coverage.page(6, challenge="security-verification")
    notice = coverage.page(8, notice="plan-inactive")
    assert challenge["complete"] is False and challenge["challenge_detected"]
    assert notice["notice"] == "plan-inactive"
    assert notice["challenge_detected"] is None


def test_social_coverage_needs_a_bounded_set_not_a_scroll_count():
    block = coverage.social(4, "DczE", False, "DfaI", "declared-limit", minimum=4)
    assert block["complete"] is True
    assert block["anchor_reached"] is False
    assert block["stopping_post"] == "DfaI"
