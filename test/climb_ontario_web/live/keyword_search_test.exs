defmodule ClimbOntarioWeb.KeywordSearchTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ClimbOntario.Fixtures

  defp query(url), do: url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

  test "debounced keyword resets depth; load more and removal preserve other filters", %{
    conn: conn
  } do
    v = venue!()

    for n <- 1..25,
        do:
          listing!(v, %{
            title: "Boulder #{n}",
            start_date: Date.add(ClimbOntario.Clock.today(), n)
          })

    {:ok, view, _} = live(conn, "/?near=Aurora&kind=competition&page=2&unscheduled=1")
    assert has_element?(view, "#keyword[phx-debounce='300']")
    refute render(view) =~ "Show them too"
    refute render(view) =~ "Hide them"
    view |> form("#keyword-search", q: "boulder") |> render_change()
    assert query(assert_patch(view)) == query("/?near=Aurora&kind=competition&q=boulder")
    assert has_element?(view, "#result-count", "Showing 20 of 25")
    view |> element("#load-more") |> render_click()
    assert query(assert_patch(view)) == query("/?near=Aurora&kind=competition&q=boulder&page=2")
    assert has_element?(view, "#result-count", "Showing 25 of 25")
    {:ok, returned, _} = live(recycle(conn), "/?near=Aurora&kind=competition&q=boulder&page=2")
    assert has_element?(returned, "#keyword[value='boulder']")
    assert has_element?(returned, "#result-count", "Showing 25 of 25")
    returned |> element("a[aria-label='Remove keyword search']") |> render_click()
    assert query(assert_patch(returned)) == query("/?near=Aurora&kind=competition")
    assert has_element?(returned, "#result-count", "Showing 20 of 25")
  end
end
