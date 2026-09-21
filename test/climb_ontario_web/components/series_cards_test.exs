defmodule ClimbOntarioWeb.SeriesCardsTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  import Phoenix.LiveViewTest
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.{Query, Series}
  alias ClimbOntarioWeb.{Format, ListingComponents}

  test "reviewed examples: Pebbles position includes past and filter-excluded sessions; meetup has no finite count" do
    for id <- [30, 10, 38], do: venue!(%{source_gym_id: id, slug: "example-#{id}"})
    Code.eval_file("priv/repo/examples.exs")

    for {today, params, date, index} <- [
          {~D[2026-09-08], %{}, ~D[2026-09-13], 1},
          {~D[2026-09-17], %{}, ~D[2026-09-20], 2},
          {~D[2026-09-17], %{"from" => "2026-10-01", "days" => "7", "page" => "2"},
           ~D[2026-10-04], 4}
        ] do
      l = Catalogue.search(Query.from_params(params, today)).dated |> Enum.find(&(&1.id == 209))
      session = Format.card_session(l, Format.card_date(l, today))
      assert session.id == l.discovery_occurrence_id
      assert session.date == l.discovery_date
      assert session.date == date
      assert Series.position(l, session) == %{index: index, total: 6}
      html = render_component(&ListingComponents.listing_card/1, listing: l, today: today)
      assert html =~ "#{index} of ~6"
      assert html =~ ~s(data-date="#{date}")
      assert html =~ "series-card"
      # Numbers come from the sessions on file; an explicit completeness assertion is not required.
      assert Series.position(%{l | complete_cohorts: []}, session) == %{index: index, total: 6}
    end

    for {id, stacked} <- [{28, true}, {17, false}] do
      l = Catalogue.get_listing(id)

      html =
        render_component(&ListingComponents.listing_card/1, listing: l, today: ~D[2026-09-17])

      assert html =~ "series-card" == stacked
      refute html =~ " of 2"
      refute html =~ " of 3"
    end
  end

  test "same-day cohorts at different gyms select the qualifying occurrence, never an aggregate number" do
    far = venue!()

    near =
      venue!(%{
        slug: "near",
        name: "Other Gym",
        city: "Toronto",
        street_address: "42 Actual St",
        lat: 43.65,
        lng: -79.38,
        website: "https://other.example"
      })

    l =
      listing!(
        far,
        %{
          kind: "class",
          schedule_kind: "course",
          title: "Youth groups",
          cohorts: ["Little kids", "Teens"],
          bundled_by: "age",
          classes: [%{name: "Little kids", ages: "4–6"}, %{name: "Teens", ages: "13–17"}],
          start_date: ~D[2026-09-01],
          end_date: ~D[2026-10-01]
        },
        [
          %{date: ~D[2026-09-01], cohort: "Teens", start_time: ~T[09:00:00]},
          %{date: ~D[2026-09-20], cohort: "Little kids", start_time: ~T[09:00:00]},
          %{
            date: ~D[2026-09-20],
            cohort: "Teens",
            start_time: ~T[10:00:00],
            location_kind: "venue",
            venue_id: near.id
          }
        ]
      )

    q = %Query{today: ~D[2026-09-17], near: %{lat: near.lat, lng: near.lng}, radius_km: 10}
    assert [result] = Catalogue.search(q).dated
    assert result.id == l.id
    selected = Format.card_session(result, result.discovery_date)
    assert selected.cohort == "Teens"
    assert selected.venue_id == near.id
    assert Series.position(result, selected) == %{index: 2, total: 2}
    html = render_component(&ListingComponents.listing_card/1, listing: result, today: q.today)
    assert html =~ "Teens"
    refute html =~ "Little kids"
    assert html =~ "https://other.example"
    assert html =~ "maps/search/?api=1&amp;query=42+Actual+St%2C+Toronto%2C+Ontario"
    refute html =~ "https://reach.example"
    refute html =~ " of 3"
    # Two named classes make a bundle: the card says so instead of counting one class's sessions.
    assert html =~ "2 classes"
    refute html =~ " of ~"
  end

  test "independent title, gym and address directions links; offsite stays offsite, unknown address has no pin" do
    l =
      listing!(venue!(), %{
        location_kind: "offsite",
        offsite_name: "Town Park",
        offsite_city: "Toronto",
        offsite_address: "123 Park Ave",
        offsite_lat: 43.6,
        offsite_lng: -79.3
      })

    html = render_component(&ListingComponents.listing_card/1, listing: l, today: ~D[2026-09-08])
    doc = LazyHTML.from_fragment(html)
    assert Enum.count(LazyHTML.query(doc, "article h3 a[href^='/e/']")) == 1
    assert Enum.count(LazyHTML.query(doc, "a[href='https://reach.example']")) == 1
    assert Enum.count(LazyHTML.query(doc, "a a")) == 0
    assert html =~ "Town Park"
    assert html =~ "maps/search/?api=1&amp;query=123+Park+Ave%2C+Toronto%2C+Ontario"
    refute html =~ "43.6"

    assert Format.map_url(%{street_address: nil, city: "Toronto", lat: 43.6, lng: -79.3}) ==
             nil

    assert Format.gym_website(%{website: "javascript:alert(1)"}) == nil
  end
end
