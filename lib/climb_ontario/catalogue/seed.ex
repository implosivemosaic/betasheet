defmodule ClimbOntario.Catalogue.Seed do
  @moduledoc """
  One-time scaffolding for the hand conversion. Reads the research database read-only and
  inserts every venue plus an UNPUBLISHED skeleton per research event carrying only the
  facts that need no judgment: id, venue, title, dates, times, sources, checked date, and
  the link. Judgment columns stay null until a researcher fills them. Existing rows are
  left alone, so re-running never overwrites conversion work.
  """
  import Ecto.Query
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Import, Listing, ResearchSource, Venue}

  def run do
    %{gyms: gyms, events: events} = ResearchSource.load()
    coords = gym_coords()
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    venue_rows =
      Enum.map(gyms, fn g ->
        c = Map.get(coords, g["id"], %{})

        %{
          source_gym_id: g["id"],
          slug: Listing.slugify(g["name"]),
          name: g["name"],
          street_address: g["street_address"],
          city: g["city"],
          postal_code: g["postal_code"],
          website: g["website"],
          lat: c["lat"],
          lng: c["lng"],
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Venue, venue_rows, on_conflict: :nothing, conflict_target: :source_gym_id)
    venues = Repo.all(from v in Venue, select: {v.source_gym_id, v.id}) |> Map.new()
    existing = Repo.all(from l in Listing, select: l.id) |> MapSet.new()

    results =
      events
      |> Enum.reject(&MapSet.member?(existing, &1["id"]))
      |> Enum.map(&Import.put_listing(skeleton(&1, Map.fetch!(venues, &1["gym_id"]))))

    %{
      venues: map_size(venues),
      skeletons: Enum.count(results, &match?({:ok, _}, &1)),
      failed: Enum.count(results, &match?({:error, _}, &1))
    }
  end

  defp skeleton(ev, venue_id) do
    %{
      id: ev["id"],
      venue_id: venue_id,
      title: ev["title"],
      start_date: ev["start_date"],
      end_date: ev["end_date"],
      start_time: ev["start_time"],
      end_time: ev["end_time"],
      link: ev["registration_url"] || first_url(ev, "website"),
      sources: ev["sources"] |> Enum.map(& &1["url"]) |> Enum.uniq(),
      checked_on: ev["checked_at"] && String.slice(ev["checked_at"], 0, 10),
      published: false
    }
  end

  defp first_url(ev, platform),
    do: ev["sources"] |> Enum.find(&(&1["platform"] == platform)) |> then(&(&1 && &1["url"]))

  defp gym_coords do
    Application.app_dir(:climb_ontario, "priv/geo/gyms.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.new(&{&1["gym_id"], &1})
  end
end
