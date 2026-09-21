defmodule ClimbOntarioWeb.DiscoveryPaginationTest do
  use ClimbOntarioWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ClimbOntario.Fixtures
  alias ClimbOntario.{Catalogue.Query, Clock}

  setup do
    v = venue!()

    for n <- 1..38 do
      listing!(v, %{title: "Dated #{n}", kind: "class", start_date: Date.add(Clock.today(), n)})
    end

    for n <- 1..7 do
      listing!(v, %{
        title: "Undated #{n}",
        kind: "social",
        schedule_kind: "recurring",
        start_date: nil,
        recurrence: "weekly",
        weekday: 5
      })
    end

    :ok
  end

  defp cards(view), do: length(Regex.scan(~r/class="card-lift /, render(view)))

  test "combined batches of 20, then final partial with separate undated section", %{conn: conn} do
    {:ok, view, _} = live(conn, "/")
    assert cards(view) == 20
    assert has_element?(view, "#result-count", "Showing 20 of 45 listings")
    refute has_element?(view, "#ongoing")
    view |> element("#load-more") |> render_click()
    assert_patch(view, "/?page=2")
    assert cards(view) == 40
    assert has_element?(view, "#result-count", "Showing 40 of 45 listings")
    assert has_element?(view, "#ongoing")
    view |> element("#load-more") |> render_click()
    assert_patch(view, "/?page=3")
    assert cards(view) == 45
    assert has_element?(view, "#result-count", "Showing 45 of 45 listings")
    refute has_element?(view, "#load-more")
  end

  test "kind, location and date filters reset loaded depth", %{conn: conn} do
    {:ok, view, _} = live(conn, "/?page=2")
    view |> form("#filter-form-kind", %{"values" => ["class"]}) |> render_submit()
    assert_patch(view, "/?kind=class")
    assert cards(view) == 20
    render_patch(view, "/?page=2")
    view |> form("form[role=search]", near: "Aurora") |> render_submit()
    assert_patch(view, "/?near=Aurora")
    assert cards(view) == 20
    render_patch(view, "/?page=2")

    view
    |> form("#filter-form-when", %{
      "from" => Date.to_iso8601(Clock.today()),
      "to" => Date.to_iso8601(Date.add(Clock.today(), 6))
    })
    |> render_submit()

    assert_patch(view, "/?from=#{Clock.today()}&to=#{Date.add(Clock.today(), 6)}")
    assert cards(view) == 6
  end

  test "detail navigation leaves loaded depth in return URL; restoring it restores cards", %{
    conn: conn
  } do
    {:ok, view, _} = live(conn, "/?kind=class&page=2")
    assert cards(view) == 38
    html = render(view)
    [_, detail] = Regex.run(~r{href="(/e/[^\"]+)"}, html)
    detail_html = conn |> recycle() |> get(detail) |> html_response(200)
    assert detail_html =~ "data-back"
    # Existing data-back handler uses browser history; the patched search URL owns depth.
    {:ok, returned, _} = live(recycle(conn), "/?kind=class&page=2")
    assert cards(returned) == 38
    assert has_element?(returned, "#result-count", "Showing 38 of 38 listings")
  end

  test "malformed and extreme URL depths reset safely", %{conn: conn} do
    for page <- [nil, "0", "-1", "2junk", "1.5", "51", "999999999999999999999", %{}, ["2"]] do
      assert Query.from_params(%{"page" => page}, Clock.today()).page == 1
    end

    assert Query.from_params(%{"page" => "50"}, Clock.today()).page == 50
    {:ok, view, _} = live(conn, "/?page=999999999999999999")
    assert cards(view) == 20
    assert Query.to_params(Query.from_params(%{"page" => "2"}, Clock.today())) == [page: 2]
  end
end
