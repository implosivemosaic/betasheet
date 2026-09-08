defmodule ClimbOntario.Catalogue.Builder do
  @moduledoc """
  Builds the public catalogue: research DB (read-only) + priv/geo/gyms.json -> venues + listings.
  Idempotent: upserts by source ids, so re-running refreshes rather than duplicates.
  """
  import Ecto.Query
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Mapper, ResearchSource, Text, Venue}

  def run(opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    %{gyms: gyms, events: events} = ResearchSource.load()
    coords = gym_coords()
    editorial = editorial()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    venue_rows = Enum.map(gyms, &venue_attrs(&1, coords, now))

    Repo.insert_all(Venue, venue_rows,
      on_conflict: {:replace_all_except, [:id, :inserted_at]},
      conflict_target: :source_gym_id
    )

    venues = Repo.all(Venue) |> Map.new(&{&1.source_gym_id, &1})

    listing_rows =
      Enum.map(events, fn ev ->
        ev
        |> Mapper.to_listing(
          Map.fetch!(venues, ev["gym_id"]),
          today,
          Map.get(editorial, to_string(ev["id"]), %{})
        )
        |> Map.merge(%{inserted_at: now, updated_at: now})
      end)

    Enum.chunk_every(listing_rows, 100)
    |> Enum.each(
      &Repo.insert_all(Listing, &1,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: :source_event_id
      )
    )

    source_ids = Enum.map(events, & &1["id"])
    Repo.delete_all(from l in Listing, where: l.source_event_id not in ^source_ids)

    %{
      venues: map_size(venues),
      listings: length(listing_rows),
      listed: Enum.count(listing_rows, & &1.listed)
    }
  end

  defp venue_attrs(gym, coords, now) do
    geo = Map.get(coords, gym["id"], %{})

    %{
      source_gym_id: gym["id"],
      slug: Text.slugify(gym["name"]),
      name: gym["name"],
      street_address: gym["street_address"],
      city: gym["city"],
      postal_code: gym["postal_code"],
      website: gym["website"],
      lat: geo["lat"],
      lng: geo["lng"],
      verification: gym["verification_status"],
      inserted_at: now,
      updated_at: now
    }
  end

  # Hand-written public copy per source event id: priv/catalogue/editorial/*.json
  defp editorial do
    Application.app_dir(:climb_ontario, "priv/catalogue/editorial")
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
    |> Enum.reduce(%{}, &Map.merge(&2, &1))
  end

  defp gym_coords do
    Application.app_dir(:climb_ontario, "priv/geo/gyms.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.new(&{&1["gym_id"], &1})
  end
end
