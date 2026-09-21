defmodule ClimbOntarioWeb.DiscoveryFiltersTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  defp params(url), do: url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

  test "labelled visible controls; default filters have no empty active row", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")

    for {id, label} <- [
          {"location", "Location"},
          {"kind", "Event type"},
          {"when", "When"},
          {"for", "Audience"}
        ] do
      assert has_element?(
               view,
               if(id == "location", do: "#location-label", else: "#sheet-label-#{id}"),
               label
             )
    end

    refute has_element?(view, "nav[aria-label='Filters'] details")
    assert has_element?(view, "#sheet-for label", "Kids & youth")
    refute has_element?(view, "#active-filters")
    assert has_element?(view, "option[value='40'][selected]")
  end

  test "individual active removals preserve other criteria and reset depth", %{conn: conn} do
    initial =
      "/?near=London&km=100&kind=ocf,class&from=2026-11-01&to=2026-11-30&for=youth,adult&page=2"

    {:ok, view, _} = live(conn, initial)
    assert has_element?(view, "#active-filters", "London · 100 km")
    assert has_element?(view, "button[data-open='sheet-kind'].btn-primary", "Event type")
    assert has_element?(view, "button[data-open='sheet-for'].btn-primary", "Audience")

    cases = [
      {"Remove event type OCF", "kind", "class"},
      {"Remove audience Kids & youth", "for", "adult"},
      {"Remove date range", "from", nil},
      {"Remove location and distance", "near", nil}
    ]

    for {label, key, value} <- cases do
      render_patch(view, initial)
      assert_patch(view, initial)
      view |> element("#active-filters a[aria-label='#{label}']") |> render_click()
      actual = params(assert_patch(view))
      expected = params(initial) |> Map.delete("page")
      expected = if value, do: Map.put(expected, key, value), else: Map.delete(expected, key)
      expected = if key == "near", do: Map.delete(expected, "km"), else: expected
      expected = if key == "from", do: Map.delete(expected, "to"), else: expected
      assert actual == expected
    end

    view |> element("a[aria-label='Clear all filters']") |> render_click()
    assert_patch(view, "/")
    refute has_element?(view, "#active-filters")
  end

  test "When range and weekday chips clear independently; shortcut populates explicit bounds", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/?near=London&page=2")

    assert has_element?(
             view,
             "#sheet-when button[data-range-from][data-range-to]",
             "This weekend"
           )

    assert has_element?(view, "#sheet-when input[type='date'][name='from']")

    for {day, n} <-
          Enum.with_index(~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday), 1) do
      assert has_element?(
               view,
               ".weekday-row input[type='checkbox'][aria-label='#{day}'][value='#{n}']"
             )
    end

    assert has_element?(view, ".when-shortcuts.grid-cols-2 button.h-11", "This weekend")
    assert has_element?(view, ".when-shortcuts.grid-cols-2 button.h-11", "Next 7 days")
    assert has_element?(view, "#sheet-for label", "LGBTQ+")

    view
    |> form("#filter-form-when", %{
      "from" => "2026-11-01",
      "to" => "2026-11-30",
      "values" => ["1", "6"]
    })
    |> render_submit()

    assert params(assert_patch(view)) == %{
             "near" => "London",
             "from" => "2026-11-01",
             "to" => "2026-11-30",
             "days" => "1,6"
           }

    view |> element("a[aria-label='Remove date range']") |> render_click()
    assert params(assert_patch(view)) == %{"near" => "London", "days" => "1,6"}
    view |> element("a[aria-label='Remove weekdays']") |> render_click()
    assert params(assert_patch(view)) == %{"near" => "London"}
  end

  test "sheets apply selections together and clear only their own group", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?near=London&kind=ocf&from=2026-11-01&to=2026-11-30&page=2")
    assert has_element?(view, "dialog#sheet-for[aria-labelledby='sheet-label-for']")
    assert has_element?(view, "#sheet-for button[data-close]", "Cancel")
    refute has_element?(view, "dialog[open]")
    view |> form("#filter-form-for", %{"values" => ["youth", "adult"]}) |> render_submit()

    assert params(assert_patch(view)) == %{
             "near" => "London",
             "kind" => "ocf",
             "from" => "2026-11-01",
             "to" => "2026-11-30",
             "for" => "youth,adult"
           }

    assert has_element?(view, "#active-filters", "Kids & youth")
    assert has_element?(view, "#active-filters", "Adults")
    view |> form("#filter-form-kind", %{"values" => []}) |> render_submit()
    refute Map.has_key?(params(assert_patch(view)), "kind")
    assert has_element?(view, "#active-filters", "London")
  end

  test "distance selector preserves search, types, audience and unknown flag but resets page", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/?near=London&kind=ocf&for=youth&page=3")
    view |> form("#distance-filter", km: "100") |> render_change()

    assert params(assert_patch(view)) == %{
             "near" => "London",
             "kind" => "ocf",
             "for" => "youth",
             "km" => "100"
           }

    assert has_element?(view, "#distance option[value='100'][selected]")
    view |> element("a[aria-label='Remove location and distance']") |> render_click()

    assert params(assert_patch(view)) == %{
             "kind" => "ocf",
             "for" => "youth"
           }

    assert has_element?(view, "#distance option[value='40'][selected]")
  end
end
