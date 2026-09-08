defmodule ClimbOntario.Fixtures do
  @moduledoc "Minimal curated rows for facade and web tests, written through the real import path."
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Import, Venue}

  def venue!(attrs \\ %{}) do
    Repo.insert!(
      struct(
        Venue,
        Map.merge(
          %{
            source_gym_id: System.unique_integer([:positive]),
            slug: "reach",
            name: "Reach Indoor Climbing",
            city: "Aurora",
            street_address: "212 Earl Stewart Dr",
            website: "https://reach.example",
            lat: 44.0,
            lng: -79.44
          },
          attrs
        )
      )
    )
  end

  def listing!(venue, attrs \\ %{}, dates \\ []) do
    base = %{
      id: System.unique_integer([:positive]),
      venue_id: venue.id,
      title: "OCF Boulder U11/U13/U15",
      kind: "competition",
      label: "OCF sanctioned",
      summary: "Provincial youth bouldering.",
      schedule_kind: "one_off",
      start_date: ~D[2026-12-12],
      audience: ["youth"],
      confidence: "confirmed",
      link: "https://ocf.example/e",
      link_kind: "event",
      checked_on: ~D[2026-09-07],
      published: true
    }

    {:ok, listing} = Import.put_listing(Map.merge(base, attrs), dates)
    Repo.preload(listing, [:venue, :occurrences])
  end
end
