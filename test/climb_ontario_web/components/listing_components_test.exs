defmodule ClimbOntarioWeb.ListingComponentsTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  import Phoenix.LiveViewTest
  alias ClimbOntario.{Catalogue, Catalogue.Query}
  alias ClimbOntarioWeb.ListingComponents

  test "date lines use the same next session as chronological sorting, including filtered windows" do
    v = venue!()

    listing!(
      v,
      %{title: "Recurring", kind: "social", schedule_kind: "recurring", start_date: nil},
      [~D[2026-09-09], ~D[2026-09-13]]
    )

    listing!(
      v,
      %{
        title: "Course",
        kind: "class",
        schedule_kind: "course",
        start_date: ~D[2026-09-01],
        end_date: ~D[2026-10-01]
      },
      [~D[2026-09-01], ~D[2026-09-10], ~D[2026-09-12]]
    )

    today = ~D[2026-09-08]

    for {params, expected} <- [
          {%{}, [{"Recurring", ~D[2026-09-09]}, {"Course", ~D[2026-09-10]}]},
          {%{"when" => "weekend"}, [{"Course", ~D[2026-09-12]}, {"Recurring", ~D[2026-09-13]}]}
        ] do
      results = Catalogue.search(Query.from_params(params, today)).dated
      assert Enum.map(results, &{&1.title, &1.discovery_date}) == expected

      for l <- results do
        html = render_component(&ListingComponents.listing_card/1, listing: l, today: today)
        assert html =~ ~s(data-date="#{l.discovery_date}")
        assert html =~ ~s(data-date="#{l.discovery_date}"[^>]*>#{ClimbOntarioWeb.Format.date(l.discovery_date)}</time>) |> Regex.compile!()
        refute html =~ "hero-arrow-path"
        refute html =~ "Dates<br"
      end
    end
  end

  test "genuinely undated recurring cards explain the fallback" do
    l =
      listing!(venue!(), %{
        kind: "social",
        schedule_kind: "recurring",
        start_date: nil,
        recurrence: "weekly",
        weekday: 5
      })

    html = render_component(&ListingComponents.listing_card/1, listing: l, today: ~D[2026-09-08])
    assert html =~ "Dates not confirmed"
    assert html =~ "TBA"
    refute html =~ "data-date="
    refute html =~ "hero-arrow-path"
  end
end
