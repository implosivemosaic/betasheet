defmodule ClimbOntarioWeb.ErrorHTMLTest do
  use ClimbOntarioWeb.ConnCase, async: true

  import Phoenix.Template, only: [render_to_string: 4]

  test "404 and 500 wear the site chrome and the climber" do
    html = render_to_string(ClimbOntarioWeb.ErrorHTML, "404", "html", [])
    assert html =~ "<!DOCTYPE html>"
    assert html =~ "Page not found"
    assert html =~ "This route doesn't go anywhere."
    assert html =~ ~s(id="climber-hero")
    assert html =~ ~s(id="climber")

    html = render_to_string(ClimbOntarioWeb.ErrorHTML, "500", "html", [])
    assert html =~ "We slipped."
    assert html =~ ~s(id="climber-hero")
  end

  test "an unknown event slug gets the styled 404" do
    conn = get(build_conn(), "/e/999999-nope")
    assert conn.status == 404
    body = html_response(conn, 404)
    assert body =~ "This route doesn't go anywhere."
    assert length(Regex.scan(~r/<html/, body)) == 1
  end

  test "other templates keep the plain status message" do
    assert render_to_string(ClimbOntarioWeb.ErrorHTML, "403", "html", []) == "Forbidden"
  end
end
