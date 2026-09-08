defmodule ClimbOntarioWeb.DiscoverLiveTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ClimbOntario.Fixtures

  setup do
    venue = venue!()

    %{
      comp: listing!(venue),
      social:
        listing!(venue, %{
          title: "Women's Night",
          kind: "social",
          schedule_kind: "recurring",
          start_date: nil,
          audience: ["women"]
        })
    }
  end

  defp query(path), do: path |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

  test "home shows upcoming listings without a location", %{conn: conn, comp: comp} do
    {:ok, view, html} = live(conn, ~p"/")
    assert html =~ "on in Ontario climbing?"
    assert html =~ comp.title
    assert has_element?(view, "a[href='/e/#{ClimbOntario.Catalogue.Listing.slug(comp)}']")
  end

  test "searching a place patches the URL and filters chips stay in it", %{conn: conn, comp: comp} do
    {:ok, view, _} = live(conn, ~p"/")
    view |> form("form[role=search]", %{near: "Aurora"}) |> render_submit()
    assert_patch(view, "/?near=Aurora")
    assert render(view) =~ "Within 40 km of"

    view |> element("a.chip", "Competitions") |> render_click()
    assert query(assert_patch(view)) == %{"near" => "Aurora", "kind" => "competition"}
    html = render(view)
    assert html =~ comp.title
    refute html =~ "Women&#39;s Night"
  end

  test "unknown place explains itself", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/?near=zzqx")
    assert html =~ "Try a city or town name"
  end
end
