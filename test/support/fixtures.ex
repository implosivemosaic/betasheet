defmodule ClimbOntario.Fixtures do
  @moduledoc "Minimal catalogue rows for web and facade tests."
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Venue}

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
            lng: -79.44,
            verification: "operator_confirmed"
          },
          attrs
        )
      )
    )
  end

  def listing!(venue, attrs \\ %{}) do
    id = System.unique_integer([:positive])

    Repo.insert!(
      struct(
        Listing,
        Map.merge(
          %{
            source_event_id: id,
            venue_id: venue.id,
            slug: "#{id}-ocf-boulder",
            title: "OCF Boulder U11/U13/U15",
            kind: "competition",
            subkind: "OCF sanctioned",
            schedule_kind: "one_off",
            status: "scheduled",
            start_date: ~D[2026-12-12],
            summary: "Provincial youth bouldering.",
            audience: ["youth"],
            confidence: "confirmed",
            registration_state: "open",
            organizer_url: "https://ocf.example/e",
            link_kind: "event",
            checked_at: ~U[2026-09-07 23:49:00Z],
            listed: true
          },
          attrs
        )
      )
    )
    |> Map.put(:venue, venue)
  end
end
