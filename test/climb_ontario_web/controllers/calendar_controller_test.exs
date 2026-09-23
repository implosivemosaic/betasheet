defmodule ClimbOntarioWeb.CalendarControllerTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue.Listing

  setup do
    v = venue!()
    l = listing!(v, %{timezone: "America/Toronto", start_time: ~T[09:00:00]}, [~D[2026-12-12]])
    %{listing: l, session: hd(l.occurrences), venue: v}
  end

  test "download is an attachment with safe headers; date-only sessions export all-day",
       %{conn: conn, listing: l, session: s, venue: v} do
    response =
      conn
      |> put_req_header("accept", "text/calendar")
      |> get("/e/#{l.id}/sessions/#{s.id}/calendar.ics")

    assert response.status == 200
    assert get_resp_header(response, "content-type") == ["text/calendar; charset=utf-8"]

    assert get_resp_header(response, "content-disposition") == [
             ~s(attachment; filename="climb-#{l.id}-#{s.id}.ics")
           ]

    assert get_resp_header(response, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(response, "cache-control") == ["no-store"]
    assert response.resp_body =~ "DTSTART:20261212T140000Z"
    assert String.replace(response.resp_body, "\r\n ", "") =~ "http://localhost"

    html = conn |> get("/e/#{Listing.slug(l)}") |> html_response(200)
    assert html =~ "/e/#{l.id}/sessions/#{s.id}/calendar.ics"
    unknown = listing!(v, %{timezone: nil, start_time: nil}, [~D[2026-12-12]])
    html = conn |> get("/e/#{Listing.slug(unknown)}") |> html_response(200)
    assert html =~ "/e/#{unknown.id}/calendar.ics"
    assert html =~ "Add to your calendar"
    response = conn |> recycle() |> get("/e/#{unknown.id}/sessions/#{hd(unknown.occurrences).id}/calendar.ics")
    assert response.status == 200
    assert response.resp_body =~ "DTSTART;VALUE=DATE:20261212"
  end

  test "unpublished, foreign sessions, timed sessions without a zone and malicious identifiers return 404", %{
    conn: conn,
    listing: l,
    session: s,
    venue: v
  } do
    draft =
      listing!(v, %{published: false, start_time: ~T[09:00:00], timezone: "America/Toronto"}, [
        ~D[2026-12-12]
      ])

    no_zone = listing!(v, %{start_time: ~T[09:00:00]}, [~D[2026-12-12]])

    for {lid, sid} <- [
          {draft.id, hd(draft.occurrences).id},
          {l.id, hd(draft.occurrences).id},
          {no_zone.id, hd(no_zone.occurrences).id},
          {l.id, "#{s.id}-evil"},
          {"#{l.id}-evil", s.id},
          {"-1", s.id},
          {l.id, "9999999999999999999999999999999999"},
          {l.id, "1%0D%0AX-Evil%3Ayes"},
          {"0", s.id},
          {"not-a-number", s.id},
          {l.id, "99999999"}
        ] do
      response = conn |> recycle() |> get("/e/#{lid}/sessions/#{sid}/calendar.ics")
      assert response.status == 404
      refute response.resp_body =~ "BEGIN:VCALENDAR"
      assert get_resp_header(response, "content-disposition") == []
    end
  end
end
