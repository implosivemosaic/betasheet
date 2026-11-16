"""What did we read? One test per outcome rule in the capture contract.

The fixtures are shaped like the real November captures, including the ones that went
wrong: a calendar that never rendered, a plan-inactive page, a soft 404 inside full site
chrome, and prose that merely says "not found".
"""
import json
import pathlib

import extract


# --------------------------------------------------------------------------- builders

def rgp(tmp_path, name="cap", months=None, series=None,
        captured_at="2026-11-17T10:00:00+00:00", txt=None, coverage=None):
    data = {"id": name, "url": "https://app.rockgympro.com/b/?bo=x",
            "captured_at": captured_at, "months": months or [], "series": series or []}
    if coverage:
        data["coverage"] = coverage
    path = tmp_path / (name + ".rgp.json")
    path.write_text(json.dumps(data))
    if txt is not None:
        (tmp_path / (name + ".rgp.txt")).write_text(txt)
    return str(path)


def rphq(tmp_path, name="cap", months=None, available=None,
         captured_at="2026-11-17T10:00:00+00:00", txt=None):
    data = {"id": name, "url": "https://portal.example.com/start/programs/x",
            "captured_at": captured_at, "months": months or [],
            "available": available or [], "details": {}}
    path = tmp_path / (name + ".rphq.json")
    path.write_text(json.dumps(data))
    if txt is not None:
        (tmp_path / (name + ".rphq.txt")).write_text(txt)
    return str(path)


def page(tmp_path, text, name="page", lines=None, url="https://example.test/x"):
    meta = {"id": name, "requested_url": url, "final_url": url, "title": "",
            "captured_at": "2026-11-17T10:00:00+00:00", "text_sha256": "0" * 64,
            "text_lines": lines if lines is not None else len(
                [line for line in text.splitlines() if line.strip()])}
    (tmp_path / (name + ".meta.json")).write_text(json.dumps(meta))
    (tmp_path / (name + ".norm.txt")).write_text(text)
    return str(tmp_path / (name + ".meta.json"))


def month(title, available=None, clicks=None):
    return {"title": title, "available": available or [],
            "clicks": [{"days": [d]} for d in (clicks or [])]}


GRID = "Mo\tTu\tWe\tTh\tFr\tSa\tSu\n26\t27\t28\t29\t30\t31\t1\n"


def ig_markdown(tmp_path, body, name="ig-profile"):
    path = tmp_path / (name + ".md")
    path.write_text(body)
    return str(path)


def social_json(tmp_path, provider, posts, coverage_block, name="cap"):
    suffix = "ig.json" if provider == "instagram" else "fb.json"
    data = {"id": name, "url": "https://example.test/feed", "provider": provider,
            "captured_at": "2026-11-17T10:00:00+00:00", "posts": posts,
            "coverage": coverage_block}
    path = tmp_path / (name + "." + suffix)
    path.write_text(json.dumps(data))
    return str(path)


# ------------------------------------------------------------------------ Rock Gym Pro

def test_no_months_is_a_failed_capture(tmp_path):
    record = extract.extract(rgp(tmp_path))
    assert record["outcome"] == extract.FAILED
    assert record["coverage"]["complete"] is False


def test_month_titles_without_grid_evidence_are_failed(tmp_path):
    path = rgp(tmp_path, months=[month("November 2026")])
    assert extract.extract(path)["outcome"] == extract.FAILED


def test_rendered_empty_calendar_is_read_empty(tmp_path):
    path = rgp(tmp_path, months=[month("November 2026")], txt=GRID)
    record = extract.extract(path)
    assert record["outcome"] == extract.READ_EMPTY
    assert record["evidence"] == "zero-available-days"


def test_declared_cell_count_is_grid_evidence(tmp_path):
    path = rgp(tmp_path, months=[month("November 2026")],
               coverage={"months_requested": 1,
                         "inspected": {"months": [{"title": "November 2026",
                                                   "cells_parsed": 35}]}})
    assert extract.extract(path)["outcome"] == extract.READ_EMPTY


def test_sorry_message_is_an_observation_not_a_session(tmp_path):
    path = rgp(tmp_path, months=[month("November 2026", available=["12"],
                                      clicks=["Sorry, but there are no available times "
                                              "for Thu, November 12"])])
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["evidence"] == "clicked-no-times"
    assert record["entries"] == []
    assert record["errors"][0]["reason"] == "no-available-times"


def test_short_read_is_partial_not_read(tmp_path):
    path = rgp(tmp_path, months=[month("November 2026", available=["13"],
                                      clicks=["Thu, November 13, 6:30 PM to 7:30 PM"])],
               coverage={"months_requested": 3})
    assert extract.extract(path)["outcome"] == extract.PARTIAL


def test_series_and_clicks_yield_the_same_entry(tmp_path):
    # A pre-`clicks` capture keeps its details only in `series`.
    via_series = extract.extract(rgp(
        tmp_path, name="a", months=[month("November 2026")],
        series=[{"days": ["Thu, November 13, 6:30 PM to 7:30 PM"]}]))
    via_clicks = extract.extract(rgp(
        tmp_path, name="b",
        months=[month("November 2026", available=["13"],
                      clicks=["Thu, November 13, 6:30 PM to 7:30 PM"])]))
    assert via_series["entries"] == via_clicks["entries"]
    assert via_series["entries"][0]["date"] == "2026-11-13"


def test_a_highlighted_date_with_no_click_is_unread_not_empty(tmp_path):
    # The grid offered the 13th and nothing asked about it: the capture knows only that
    # the date was never resolved, so it is a gap rather than an absence of sessions.
    record = extract.extract(rgp(tmp_path, months=[month("November 2026", available=["13"])],
                                 txt=GRID))
    assert record["outcome"] == extract.PARTIAL
    assert record["entries"] == []
    assert record["days"]["unread"] == 1
    assert record["coverage"]["complete"] is False


def test_year_comes_from_the_month_title(tmp_path):
    path = rgp(tmp_path, months=[month("January 2027")],
               series=[{"days": ["Day #1: Thu, Jan 7, 4:30 PM to 6:30 PM"]}])
    entry = extract.extract(path)["entries"][0]
    assert (entry["date"], entry["start"], entry["end"]) == ("2027-01-07", "16:30", "18:30")


def test_course_spanning_december_january_takes_each_month_s_own_year(tmp_path):
    path = rgp(tmp_path, months=[month("December 2026"), month("January 2027")],
               series=[{"days": ["Thu, December 17, 6 PM to 7 PM",
                                 "Sun, January 3, 6 PM to 7 PM"]}])
    dates = sorted(e["date"] for e in extract.extract(path)["entries"])
    assert dates == ["2026-12-17", "2027-01-03"]


def test_repeated_month_in_window_leaves_the_year_unresolved(tmp_path):
    path = rgp(tmp_path, months=[month("December 2026"), month("December 2027")],
               series=[{"days": ["Thu, December 17, 6 PM to 7 PM"]}])
    entry = extract.extract(path)["entries"][0]
    assert entry["date"] is None and entry["year_inferred"] is True


def test_day_number_is_evidence_not_identity(tmp_path):
    one = extract.extract(rgp(tmp_path, name="w1", months=[month("January 2027")],
                              series=[{"days": ["Day #1: Thu, Jan 7, 6 PM to 7 PM"]}]))
    two = extract.extract(rgp(tmp_path, name="w2", months=[month("January 2027")],
                              series=[{"days": ["Day #8: Thu, Jan 7, 6 PM to 7 PM"]}]))
    identity = lambda e: (e["date"], e["start"], e["end"], e["state"], e["cohort"])
    assert identity(one["entries"][0]) == identity(two["entries"][0])
    assert one["entries"][0]["raw"].startswith("Day #1")
    assert two["entries"][0]["raw"].startswith("Day #8")


# ---------------------------------------------------------------------------- Redpoint

def cells(count, available=()):
    out = [{"label": "November %d, 2026" % (d + 1), "state": "unmarked",
            "disabled": False, "other_month": False} for d in range(count)]
    for index in available:
        out[index] = {"label": "November %d, 2026, Available" % (index + 1),
                      "state": "available", "disabled": False, "other_month": False}
    return [{"title": "November 2026", "cells": out,
             "available": [c["label"] for c in out if c["state"] == "available"]}]


def test_redpoint_cells_with_dates_are_read(tmp_path):
    path = rphq(tmp_path, months=cells(30, available=[22, 24]),
                available=["November 23, 2026, Available",
                           "November 25, 2026, Available"])
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert [e["date"] for e in record["entries"]] == ["2026-11-23", "2026-11-25"]


def test_redpoint_cells_without_availability_are_read_empty(tmp_path):
    record = extract.extract(rphq(tmp_path, months=cells(30)))
    assert record["outcome"] == extract.READ_EMPTY


def test_error_months_with_a_readable_offering_page_baseline_the_page_only(tmp_path):
    # The description is readable and the calendar markup is not. That is a page
    # baseline with a calendar gap: no session claim may come out of it.
    path = rphq(tmp_path, months=[{"error": "no calendar cells"}],
                txt="CLIMBERSROCK.COM\nClimber's Rock\nYouth Program - Tykes\n"
                    "Weekly classes for ages 6 to 9, Tuesdays from 4pm.\nBook Now\n"
                    "Contact us\nSign In / Register\nPowered by Redpoint HQ")
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["evidence"] == "page-only"
    assert record["calendar_observed"] is False
    assert record["coverage"]["contract"] == "web-page"
    assert record["notice"] is None


def test_a_booking_header_without_a_description_is_not_a_page_baseline(tmp_path):
    # The real Aspire Whitby capture: gym name, address, phone, url, portal chrome.
    path = rgp(tmp_path, txt="\t\nAspire Climbing Whitby\n"
                             "1400 Victoria St E Unit 4 Whitby ON, L1N0M2\n"
                             "905 430 9813\nhttps://www.aspireclimbing.com  "
                             "whitby@aspireclimbing.com\n\n"
                             " Save time!  Log In or Create Profile\nPowered by Rock Gym Pro\n")
    record = extract.extract(path)
    assert record["outcome"] == extract.FAILED
    assert record["page"]["has_description"] is False
    assert record["calendar_observed"] is False


def test_an_offering_description_with_portal_chrome_is_a_page_baseline(tmp_path):
    path = rgp(tmp_path, txt="\t\nBoulderz Etobicoke\n80 The East Mall Unit 9 Etobicoke, ON M8Z 5X1\n"
                             "(416) 255-6676\nhttps://boulderzclimbing.com/  "
                             "etobicoke@boulderzclimbing.com\n\n"
                             " Save time!  Log In or Create Profile\nLead Course - Day 2\n\n"
                             "Email us if you are interested in taking the course and we will "
                             "schedule a date.\n\nPowered by Rock Gym Pro\n")
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["evidence"] == "page-only"
    assert record["page"]["has_description"] is True


def test_error_months_with_no_readable_page_are_a_gap(tmp_path):
    path = rphq(tmp_path, months=[{"error": "no calendar cells"}], txt="")
    record = extract.extract(path)
    assert record["outcome"] == extract.FAILED
    assert record["calendar_observed"] is False


def test_same_error_shape_is_a_notice_when_the_page_says_why(tmp_path):
    path = rphq(tmp_path, months=[{"error": "no calendar cells"}],
                txt="ETHOS CLIMBING\nOops!\nThis plan is inactive. If you are attempting "
                    "to make a booking, contact the facility.\nPowered by Redpoint HQ")
    record = extract.extract(path)
    assert record["outcome"] == extract.FAILED
    assert record["notice"] == "plan-inactive"


# --------------------------------------------------------------------------------- page

def test_live_challenge_is_unreadable(tmp_path):
    record = extract.extract(page(tmp_path, "www.altrock.co\nPerforming security "
                                "verification\nThis website uses a security service\n"
                                "Ray ID: 8c1\n"))
    assert record["outcome"] == extract.FAILED
    assert record["challenge"] == "security-verification"


def test_javascript_shell_is_unreadable(tmp_path):
    record = extract.extract(page(tmp_path, "You need to enable JavaScript to run this app."))
    assert record["outcome"] == extract.FAILED


def test_bare_404_document_is_unreadable(tmp_path):
    record = extract.extract(page(tmp_path, "404\nNOT FOUND\nRETURN HOME"))
    assert record["outcome"] == extract.FAILED


def test_soft_404_inside_site_chrome_is_unreadable(tmp_path):
    chrome = "\n".join(["Skip to content", "Find Your Climbing Style", "Markham",
                        "Prices", "Plan Your Visit", "Memberships", "Youth",
                        "Oops, This page not found!", "404",
                        "The Page you looking for doesn't exist.",
                        "Regular Hours of Operation", "Address", "Hub Climbing"])
    record = extract.extract(page(tmp_path, chrome))
    assert record["outcome"] == extract.FAILED
    assert record["challenge"] == "page-not-found-oops"


def test_squarespace_404_with_long_boilerplate_is_unreadable(tmp_path):
    body = "\n".join(["Cart 0", "Specials Pricing Programs Events About Waiver Shop"] * 6
                     + ["Oops!", "We couldn't find the page you were looking for. "
                        "This is either because:", "There is an error in the URL"])
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.FAILED


def test_marketing_copy_saying_not_found_is_a_real_page(tmp_path):
    body = "\n".join(["Hub Climbing Mississauga", "Adventure Hub parties",
                      "Access to unique challenges and adventures not found anywhere "
                      "else in the GTA", "Book Now", "Hours", "Saturday 10:15am - 6pm",
                      "Sunday 10:15am - 6pm", "Monday 12:15pm - 4pm"])
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.READ
    assert record["challenge"] is None


def test_recaptcha_footer_is_a_real_page(tmp_path):
    body = "\n".join(["Of Rock and Chalk", "Learn the Ropes", "A two hour intro to belay",
                      "Private lessons available", "Book a climb", "Hours of operation",
                      "Monday to Friday 10am to 10pm", "Saturday 9am to 9pm",
                      "This site is protected by reCAPTCHA and the Google Privacy Policy "
                      "and Terms of Service apply."])
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.READ


def test_short_but_real_programme_page_is_read(tmp_path):
    body = ("Kids Program\nOur school holiday program runs 9am to 3pm on PA days for "
            "ages 6 to 12.\nRegistration opens two weeks before each date.\nCall the gym "
            "to book a spot.")
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.READ


def test_nothing_here_is_a_notice_not_an_empty_calendar(tmp_path):
    body = "Guelph Grotto\nContact Us\nSign In / Register\nOops!\nThere is nothing here\n" \
           "Back to Home\nPowered by Redpoint HQ"
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.FAILED
    assert record["notice"] == "nothing-here"


def test_deleted_file_is_a_notice(tmp_path):
    body = "Drive\nDésolé, le fichier que vous avez demandé a été supprimé.\n" \
           "Vérifiez que vous disposez de la bonne URL.\nGagnez en efficacité avec Google Drive."
    assert extract.extract(page(tmp_path, body))["notice"] == "file-deleted"


def test_a_page_quoting_an_error_message_stays_readable(tmp_path):
    body = "\n".join([
        "Troubleshooting your booking",
        "If the calendar will not load, your browser may be showing a security check.",
        "A common message is Performing security verification, sometimes followed by a",
        "Ray ID. Waiting a few seconds and reloading usually clears it.",
        "If you instead see Error: Page Not Found, the link has probably changed;",
        "use the program menu above.",
        "Members can book 14 days ahead, non-members 7 days ahead.",
        "Questions? Call the front desk between 10am and 8pm.",
        "We update this page whenever a program changes.",
        "Last reviewed November 2026.",
    ])
    record = extract.extract(page(tmp_path, body))
    assert record["outcome"] == extract.READ
    assert record["challenge"] is None


def test_shell_phrase_mention_inside_prose_stays_a_page(tmp_path):
    body = "\n".join(["Programming at the gym", "We teach beginners to check their "
                      "browser settings before registering.", "Every class runs weekly "
                      "for six weeks.", "Members get priority booking.",
                      "Contact the front desk with questions."])
    assert extract.extract(page(tmp_path, body))["outcome"] == extract.READ


# ------------------------------------------------------------------------ social: structure


def test_structured_social_capture_with_complete_coverage_is_read(tmp_path):
    path = social_json(tmp_path, "instagram", [
        {"id": "AAA", "caption": "Adult intro course starts January 5", "published": "2026-11-16"},
        {"id": "BBB", "caption": "Winter youth program, eight Thursdays", "published": "2026-11-10"},
    ], {"posts_requested": 4, "posts_fully_read": 2, "complete": True,
        "anchor_id": "BBB", "anchor_reached": True, "stopping_post": "BBB",
        "stopped_reason": "anchor-reached"})
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["coverage"]["complete"] is True
    assert [p["id"] for p in record["posts"]] == ["AAA", "BBB"]
    assert all(p["text_sha"] for p in record["posts"])


def test_structured_social_capture_short_of_its_window_is_partial(tmp_path):
    path = social_json(tmp_path, "instagram",
                       [{"id": "AAA", "caption": "One post only, read in full"}],
                       {"posts_requested": 6, "posts_fully_read": 1, "complete": False,
                        "stopping_post": "AAA", "stopped_reason": "declared-limit"})
    record = extract.extract(path)
    assert record["outcome"] == extract.PARTIAL
    assert record["coverage"]["complete"] is False


def test_facebook_post_and_photo_ids_stay_distinct(tmp_path):
    path = social_json(tmp_path, "facebook", [
        {"post_id": "1234567890", "photo_ids": ["9876543210"],
         "caption": "New winter schedule is up", "published": "2026-11-14",
         "alts": ["May be an image of text"]},
    ], {"posts_requested": 6, "posts_fully_read": 1, "complete": True,
        "anchor_id": "1234567890", "anchor_reached": True})
    record = extract.extract(path)
    kinds = {(p["id"], p["kind"]) for p in record["posts"]}
    assert kinds == {("1234567890", "post"), ("9876543210", "photo")}
    assert record["outcome"] == extract.READ


def test_historical_instagram_summary_is_partial_never_read(tmp_path):
    body = ("# Instagram \u2014 basecampclimbing_qw\n\nurl: https://www.instagram.com/x/\n\n"
            "newest post: https://www.instagram.com/altitudegym/p/DfnXI29u3It/\n"
            "newest post date: 2026-11-11\n\n## candidate posts\n\n"
            "- 2026-11-11 | https://www.instagram.com/altitudegym/p/DfnXI29u3It/ | "
            "Liked by ontarioclimbingfederation and 163 others\n"
            "- 2026-10-02 | https://www.instagram.com/altitudegym/reel/DbO4UlgJW_4/ | "
            "Adult intro course, Tuesdays 6:30pm\n\n## newest post text\n\n"
            "Our women's board clinics are back on 26 November, 6pm to 8pm.\n")
    record = extract.extract(ig_markdown(tmp_path, body))
    assert record["outcome"] == extract.PARTIAL
    assert record["coverage"]["complete"] is False


def test_historical_summary_keeps_the_newest_post_date(tmp_path):
    body = ("## candidate posts\n\n"
            "newest post: https://www.instagram.com/gym/p/AAA/\n"
            "newest post date: 2026-11-11\n\n## newest post text\n\n"
            "Winter schedule is live now, eight Thursdays from January.\n")
    record = extract.extract(ig_markdown(tmp_path, body))
    assert record["posts"][0]["published"] == "2026-11-11"


def test_single_post_summary_hashes_its_caption_and_ignores_engagement_text(tmp_path):
    body = ("## https://www.instagram.com/altitudegym/p/DfnXI29u3It/\n\n"
            "desc: 84 likes, 0 comments - altitudegym on November 11, 2026\n\n"
            "Post\naltitudegym\nLiked by ontarioclimbingfederation and 163 others\n"
            "\nOur women's board clinics are back on 26 November, 6pm to 8pm.\n")
    record = extract.extract(ig_markdown(tmp_path, body, name="ig-post-full"))
    post_record = record["posts"][0]
    assert post_record["text_sha"] is not None
    assert "liked by" not in post_record["text_sha"]


def test_a_profile_snippet_becomes_content_but_engagement_text_does_not(tmp_path):
    body = ("## candidate posts\n\n"
            "- 2026-10-02 | https://www.instagram.com/gym/reel/AAA/ | "
            "Adult intro course, Tuesdays 6:30pm\n"
            "- 2026-09-20 | https://www.instagram.com/gym/p/BBB/ | "
            "Liked by 163 others\n")
    record = extract.extract(ig_markdown(tmp_path, body))
    hashes = {p["id"]: p["text_sha"] for p in record["posts"]}
    assert hashes["AAA"] is not None
    assert hashes["BBB"] is None


# ------------------------------------------------------- F6: the month sequence is coverage

def rgp_panels(tmp_path, panels, name="cap", txt=GRID):
    data = {"id": name, "url": "https://app.rockgympro.com/b/?bo=x",
            "captured_at": "2026-11-17T10:00:00+00:00", "months": panels, "series": []}
    path = tmp_path / (name + ".rgp.json")
    path.write_text(json.dumps(data))
    (tmp_path / (name + ".rgp.txt")).write_text(txt)
    return str(path)


def panel(title, days=(), clicks=()):
    return {"title": title, "cells_parsed": 35,
            "headers": ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"],
            "available": list(days), "clicks": [dict(c) for c in clicks]}


def session(selected, line):
    return {"date_selected": selected, "days": [line]}


def test_a_skipped_month_is_a_stated_gap_not_a_complete_read(tmp_path):
    # November, then January, then February: three panels, three months claimed, and
    # December never read. This is the live capture's exact shape.
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["21"], [session("Date Selected: Sat, November 21",
                                                "Sat, November 21, 9 AM to 11 AM")]),
        panel("January 2027", ["9"], [session("Date Selected: Sat, January 9",
                                              "Sat, January 9, 9 AM to 11 AM")]),
        panel("February 2027", ["6"], [session("Date Selected: Sat, February 6",
                                               "Sat, February 6, 9 AM to 11 AM")]),
    ]))
    assert record["outcome"] == extract.PARTIAL
    assert record["coverage"]["complete"] is False
    assert record["coverage"]["months_observed"] == ["November 2026", "January 2027",
                                                     "February 2027"]
    assert any("December 2026" in problem for problem in record["coverage"]["problems"])
    # The sessions that were read are still reported: a gap is not a reason to lose them.
    assert len(record["entries"]) == 3


def test_a_duplicated_month_is_not_complete(tmp_path):
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["13"], [session("Date Selected: Thu, November 13",
                                                "Thu, November 13, 6 PM to 7 PM")]),
        panel("November 2026", ["13"], [session("Date Selected: Thu, November 13",
                                                "Thu, November 13, 6 PM to 7 PM")]),
        panel("January 2027"),
    ]))
    assert record["outcome"] == extract.PARTIAL
    assert record["coverage"]["complete"] is False
    assert any("appears twice" in problem for problem in record["coverage"]["problems"])


def test_a_contiguous_window_is_complete(tmp_path):
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["13"], [session("Date Selected: Thu, November 13",
                                                "Thu, November 13, 6 PM to 7 PM")]),
        panel("December 2026", ["4"], [session("Date Selected: Fri, December 4",
                                               "Fri, December 4, 6 PM to 7 PM")]),
        panel("January 2027"),
    ]))
    assert record["outcome"] == extract.READ
    assert record["coverage"]["complete"] is True


# ------------------------------------------- F7: every highlighted date is accounted for

def test_a_footer_only_response_is_an_unread_date_not_an_empty_one(tmp_path):
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["15", "16"], [
            session("Date Selected: Sun, November 15", "Powered by Rock Gym Pro"),
            session("Date Selected: Mon, November 16",
                    "Mon, November 16, 3 PM to 4:30 PM"),
        ]),
    ]))
    assert record["outcome"] == extract.PARTIAL
    assert record["days"] == {"highlighted": 2, "clicked": 2, "read": 1,
                              "no_available_times": 0, "unread": 1}
    assert [e["date"] for e in record["entries"]] == ["2026-11-16"]
    assert record["unread"][0]["day"] == 15
    assert record["unread"][0]["month"] == 11
    assert record["coverage"]["complete"] is False


def test_one_click_recorded_twice_is_one_observation(tmp_path):
    # The same detail appears in `clicks` and in the deduplicated `series`: two views of
    # one answer, which used to read as two parse errors.
    answer = session("Date Selected: Sun, November 15", "Powered by Rock Gym Pro")
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["15"], [answer]),
    ]))
    data = json.load(open(str(tmp_path / "cap.rgp.json")))
    data["series"] = [{"days": ["Powered by Rock Gym Pro"]}]
    (tmp_path / "cap.rgp.json").write_text(json.dumps(data))
    again = extract.extract(str(tmp_path / "cap.rgp.json"))
    assert record["unread"] == again["unread"]
    assert len(again["unread"]) == 1
    assert again["errors"] == []


def test_no_available_times_is_an_answer_not_an_unread_date(tmp_path):
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["15"], [
            session("Date Selected: Sun, November 15",
                    "Sorry, but there are no available times for Sun, November 15")]),
    ]))
    assert record["days"]["no_available_times"] == 1
    assert record["days"]["unread"] == 0
    assert record["outcome"] == extract.READ
    assert record["coverage"]["complete"] is True


# --------------------------------------------- F6: a Redpoint title derived from its cells

def test_a_redpoint_month_title_is_recovered_from_its_cells(tmp_path):
    import copy
    path = rphq(tmp_path, months=[{"cells": [
        {"label": "November 3, 2026, Full/Closed"}, {"label": "November 4, 2026, Available"},
        {"label": "November 5, 2026, Full/Closed"}], "available": [
            "November 4, 2026, Available"]}])
    record = extract.extract(path)
    assert record["coverage"]["months_observed"] == ["November 2026"]
    assert [e["date"] for e in record["entries"]] == ["2026-11-04"]


# ------------------------------------- a page-only capture declares page coverage, not a gap

def test_a_live_style_page_only_capture_is_read_not_partial(tmp_path):
    # The live tool writes what it actually knows: an offering description with no
    # calendar markup. There is no month sequence to be incomplete about.
    path = rgp(tmp_path, name="live", txt="\t\nBoulderz Etobicoke\n"
               "80 The East Mall Unit 9 Etobicoke, ON M8Z 5X1\n"
               "(416) 255-6676\nhttps://boulderzclimbing.com/\n\n"
               " Save time!  Log In or Create Profile\nLead Course - Day 2\n\n"
               "Email us if you are interested and we will schedule a date.\n\n"
               "Powered by Rock Gym Pro\n")
    data = json.load(open(path))
    data["coverage"] = {"contract": "web-page", "months_requested": 1, "months_read": 1,
                        "window": {"first": None, "last": None},
                        "inspected": {"lines": 11}, "challenge_detected": None,
                        "notice": None, "complete": True, "problems": [], "errors": []}
    pathlib.Path(path).write_text(json.dumps(data))
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["evidence"] == "page-only"
    assert record["calendar_observed"] is False
    assert record["coverage"]["complete"] is True
    assert record["coverage"]["problems"] == []


def test_a_stale_calendar_coverage_block_cannot_break_a_page_only_read(tmp_path):
    # Captures written before the fix declared three requested months and no panels.
    # That is a statement about a window that never existed; the page is still readable.
    path = rgp(tmp_path, name="stale", txt="\t\nJunction Climbing Centre\n"
               "1030 Elias Street, Unit 2 London, ON N5W3P6\n519-438-1717\n\n"
               " Save time!  Log In or Create Profile\nLemurs 3 (born 2017-2020)\n\n"
               "This is the advanced level development program for kids.\n\n"
               "Powered by Rock Gym Pro\n")
    data = json.load(open(path))
    data["coverage"] = {"contract": "calendar-3-months", "months_requested": 3,
                        "months_read": 0, "complete": False,
                        "problems": ["no month was read"], "errors": []}
    pathlib.Path(path).write_text(json.dumps(data))
    record = extract.extract(path)
    assert record["outcome"] == extract.READ
    assert record["evidence"] == "page-only"
    assert record["coverage"]["complete"] is True


def test_a_live_style_partial_calendar_keeps_its_additions(tmp_path):
    # The live Rock Gym Pro capture: one highlighted date answered nothing. The read
    # sessions are still observations, so the record is partial and the comparison keeps
    # them as provisional additions.
    record = extract.extract(rgp_panels(tmp_path, [
        panel("November 2026", ["15", "16"], [
            session("Date Selected: Sun, November 15", "Powered by Rock Gym Pro"),
            session("Date Selected: Mon, November 16", "Mon, November 16, 3 PM to 4:30 PM"),
        ]),
    ]))
    assert record["outcome"] == extract.PARTIAL
    assert [e["date"] for e in record["entries"]] == ["2026-11-16"]
    assert record["coverage"]["complete"] is False
