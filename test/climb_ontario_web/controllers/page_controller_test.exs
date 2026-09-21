defmodule ClimbOntarioWeb.PageControllerTest do
  use ClimbOntarioWeb.ConnCase, async: true

  test "the About page explains the site and gives the contact address; header and footer link to it" do
    html = build_conn() |> get("/about") |> html_response(200)
    assert html =~ "About Beta Sheet"
    assert html =~ "built by Keith"
    assert html =~ "checked by hand"
    assert html =~ "mailto:" <> ClimbOntario.contact_email()
    assert html =~ ~s(<title phx-r data-default="Beta Sheet" data-suffix=" · Beta Sheet">About · Beta Sheet</title>)
    assert length(Regex.scan(~r/href="\/about"/, html)) == 2
  end
end
