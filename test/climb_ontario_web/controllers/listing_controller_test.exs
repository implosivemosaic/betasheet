defmodule ClimbOntarioWeb.ListingControllerTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import ClimbOntario.Fixtures

  alias ClimbOntario.Catalogue.Listing

  setup do
    %{listing: listing!(venue!())}
  end

  test "drafts have no page", %{conn: conn} do
    draft = listing!(venue!(%{slug: "v2"}), %{title: "Draft", published: false})
    assert conn |> get("/e/#{Listing.slug(draft)}") |> html_response(404)
  end

  test "event page renders with link-preview tags and organizer link", %{conn: conn, listing: l} do
    html = conn |> get(~p"/e/#{Listing.slug(l)}") |> html_response(200)
    assert html =~ ~s(<meta property="og:title" content="#{l.title}")
    assert html =~ ~r{og:url" content="http://localhost(:\d+)?/e/#{Listing.slug(l)}"}
    assert html =~ "https://ocf.example/e"
    assert html =~ "Sat Dec 12"
    assert html =~ "Copy link"
    assert html =~ "View official event"
  end

  test "stale slug redirects to the canonical one; unknown id is 404", %{conn: conn, listing: l} do
    conn = get(conn, "/e/#{l.id}-old-title")
    assert redirected_to(conn, 301) == "/e/#{Listing.slug(l)}"
    assert conn |> recycle() |> get("/e/999999-nope") |> html_response(404)
    assert conn |> recycle() |> get("/e/nope") |> html_response(404)
  end
end
