defmodule ClimbOntarioWeb.SavedSearchesTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @search "/?for=youth&kind=class&near=London"

  test "a filtered search can be saved, and the browser is told to keep it", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    refute has_element?(view, "#save-search")

    {:ok, view, _} = live(conn, @search)
    assert has_element?(view, "#save-search", "Save search")

    view |> element("#save-search") |> render_click()
    assert_push_event(view, "saved_searches", %{paths: [@search]})
    assert has_element?(view, "#save-search[aria-pressed='true']", "Search saved")
  end

  test "saved searches show as named chips when no filter is on, and can be removed", %{
    conn: conn
  } do
    conn = put_connect_params(conn, %{"saved_searches" => [@search, "javascript:alert(1)"]})
    {:ok, view, _} = live(conn, "/")

    assert has_element?(
             view,
             "#saved-searches a[href='#{@search}']",
             "Classes · Kids & youth · London"
           )

    refute has_element?(view, "#saved-searches a[href^='javascript']")

    view |> element("#saved-searches button[phx-value-path='#{@search}']") |> render_click()
    assert_push_event(view, "saved_searches", %{paths: []})
    refute has_element?(view, "#saved-searches")

    {:ok, view, _} = live(conn, @search)
    refute has_element?(view, "#saved-searches")
  end
end
