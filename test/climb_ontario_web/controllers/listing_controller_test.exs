defmodule ClimbOntarioWeb.ListingControllerTest do
  use ClimbOntarioWeb.ConnCase, async: true
  import ClimbOntario.Fixtures

  setup do
    %{listing: listing!(venue!())}
  end

  test "event page renders with link-preview tags and organizer link", %{conn: conn, listing: l} do
    html = conn |> get(~p"/e/#{l.slug}") |> html_response(200)
    assert html =~ ~s(<meta property="og:title" content="#{l.title}")
    assert html =~ ~r{og:url" content="http://localhost(:\d+)?/e/#{l.slug}"}
    assert html =~ "https://ocf.example/e"
    assert html =~ "Sat Dec 12"
    assert html =~ "Copy link"
  end

  test "stale slug redirects to the canonical one; unknown id is 404", %{conn: conn, listing: l} do
    conn = get(conn, "/e/#{l.source_event_id}-old-title")
    assert redirected_to(conn, 301) == "/e/#{l.slug}"
    assert conn |> recycle() |> get("/e/999999-nope") |> html_response(404)
    assert conn |> recycle() |> get("/e/nope") |> html_response(404)
  end
end
