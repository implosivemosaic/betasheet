"""What did we read? One test per outcome rule in the capture contract.

The fixtures are shaped like the real November captures, including the ones that went
wrong: a calendar that never rendered, a plan-inactive page, a soft 404 inside full site
chrome, and prose that merely says "not found".
"""
import json

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
    via_series = extract.extract(rgp(
        tmp_path, name="a",
        months=[month("November 2026", available=["13"])],
        series=[{"days": ["Thu, November 13, 6:30 PM to 7:30 PM"]}]))
    via_clicks = extract.extract(rgp(
        tmp_path, name="b",
        months=[month("November 2026", available=["13"],
                      clicks=["Thu, November 13, 6:30 PM to 7:30 PM"])]))
    assert via_series["entries"] == via_clicks["entries"]
    assert via_series["entries"][0]["date"] == "2026-11-13"


def test_year_comes_from_the_month_title(tmp_path):
    path = rgp(tmp_path, months=[month("January 2027", available=["7"])],
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
