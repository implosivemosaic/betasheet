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
    assert html =~ "Sat Dec 12, 2026"
    assert html =~ "212 Earl Stewart Dr, Aurora"
    assert html =~ "Last updated: #{ClimbOntarioWeb.Format.updated(l.catalogue_updated_on)}"
    refute html =~ "Sources checked"
    refute html =~ "Catalogue updated"
    refute html =~ "Sep 7, 2026"
    assert html =~ "View original event"
    # share belongs to our page and sits in the header, away from the outbound CTA
    assert :binary.match(html, "data-share") < :binary.match(html, "leading-relaxed")
    assert :binary.match(html, "Where") < :binary.match(html, "View original event")
    refute html =~ "Sources:"

    gym_only =
      listing!(venue!(%{slug: "other", source_gym_id: 999}), %{
        id: 4242,
        link_kind: "gym",
        link: "https://gym.example"
      })

    assert conn
           |> recycle()
           |> get("/e/#{gym_only.id}-ocf-boulder-u11-u13-u15")
           |> html_response(200) =~
             "Visit organizer&#39;s website"
  end

  test "confirmed sessions are collapsed with shared place and timezone shown once", %{
    conn: conn,
    listing: l
  } do
    {:ok, l} =
      ClimbOntario.Catalogue.Import.put_listing(%{id: l.id, timezone: "America/Toronto"}, [
        %{date: "2026-12-12", start_time: "09:00:00"},
        %{date: "2026-12-12", start_time: "14:00:00"}
      ])

    html = conn |> get(~p"/e/#{Listing.slug(l)}") |> html_response(200)
    assert html =~ "Known schedule (2 dated)"
    refute html =~ "<details open"
    assert length(String.split(html, "America/Toronto")) == 2
    assert length(String.split(html, "212 Earl Stewart Dr")) == 2
    assert html =~ "9 am"
    assert html =~ "2 pm"
    assert html =~ "View original event"
  end

  test "known schedule renders past and next states and hides title-only description", %{
    conn: conn,
    listing: l
  } do
    today = ClimbOntario.Clock.today()

    {:ok, l} =
      ClimbOntario.Catalogue.Import.put_listing(
        %{
          id: l.id,
          schedule_kind: "course",
          start_date: Date.add(today, -7),
          end_date: Date.add(today, 7),
          summary: l.title
        },
        [Date.add(today, -7), Date.add(today, 1), Date.add(today, 7)]
      )

    html = conn |> get(~p"/e/#{Listing.slug(l)}") |> html_response(200)
    assert html =~ "Known schedule (3 dated)"
    assert html =~ ~s(data-session-state="past")
    assert html =~ ~s(data-session-state="next")
    assert html =~ ~s(data-session-state="future")
    assert html =~ ClimbOntarioWeb.Format.date_with_year(Date.add(today, -7))
    refute html =~ "leading-relaxed"
  end

  test "legacy rows omit the public timestamp rather than expose the evidence date", %{
    conn: conn,
    listing: l
  } do
    l |> Ecto.Changeset.change(catalogue_updated_on: nil) |> ClimbOntario.Repo.update!()
    html = conn |> get(~p"/e/#{Listing.slug(l)}") |> html_response(200)
    refute html =~ "Last updated"
    refute html =~ "Sources checked"
    refute html =~ "Catalogue updated"
    refute html =~ "Sep 7, 2026"
  end

  test "page generates cohort, time and offsite-city lines without researcher schedule prose", %{
    conn: conn,
    listing: l
  } do
    {:ok, l} =
      ClimbOntario.Catalogue.Import.put_listing(
        %{
          id: l.id,
          ocf: true,
          cohorts: ["Morning", "Evening"],
          bundled_by: "day",
          label: "WRONG BADGE",
          schedule_note: "DO NOT RENDER THIS SCHEDULE",
          sources: ["https://private-evidence.example/path"],
          location_kind: "offsite",
          offsite_name: "Park",
          offsite_city: "Toronto",
          offsite_address: "10 Park Rd"
        },
        [
          %{
            date: "2026-12-12",
            cohort: "Morning",
            start_time: "09:00:00",
            end_time: "11:00:00",
            timezone: "America/Toronto"
          },
          %{
            date: "2026-12-12",
            cohort: "Evening",
            start_time: nil,
            timezone: nil,
            location_kind: "unknown"
          }
        ]
      )

    html = conn |> get(~p"/e/#{Listing.slug(l)}") |> html_response(200)

    for text <- [
          "OCF competition",
          "Morning",
          "Evening",
          "9–11 am",
          "America/Toronto",
          "Park · Toronto",
          "10 Park Rd",
          "Time not announced",
          "Timezone not confirmed",
          "Venue not announced",
          "Multiple venues"
        ] do
      assert html =~ text
    end

    refute html =~ "WRONG BADGE"
    refute html =~ "DO NOT RENDER THIS SCHEDULE"
    refute html =~ "private-evidence.example"
  end

  test "stale slug redirects to the canonical one; unknown id is 404", %{conn: conn, listing: l} do
    conn = get(conn, "/e/#{l.id}-old-title")
    assert redirected_to(conn, 301) == "/e/#{Listing.slug(l)}"
    assert conn |> recycle() |> get("/e/999999-nope") |> html_response(404)
    assert conn |> recycle() |> get("/e/nope") |> html_response(404)
  end
end
