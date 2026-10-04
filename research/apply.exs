# Applies approved proposals from a run's proposals.json through the importer.
# Run by research/apply.sh (dev or prod); not by hand. The proposals JSON arrives in
# Process.get(:proposals). Each approved entry is written in its own transaction, and
# one "APPLIED {json}" line is printed per entry for the run's applied.json.
#
# Entry: {"approved": true, "action": "new" | "update", "gym": "Junction Climbing Centre",
#         "id": 312 (updates; new entries get the next free ID), "attrs": {...listing columns...},
#         "sessions": [...] or null (null keeps existing sessions), "evidence": {...}}
import Ecto.Query
alias ClimbOntario.Repo
alias ClimbOntario.Catalogue.{Import, Listing, Venue}

entries = Process.get(:proposals) |> Jason.decode!() |> Enum.filter(&(&1["approved"] == true))
next_id = (Repo.one(from l in Listing, select: max(l.id)) || 0) + 1
today = Date.utc_today() |> Date.to_iso8601()

Enum.reduce(entries, next_id, fn e, next_id ->
  venue = e["gym"] && Repo.get_by(Venue, name: e["gym"])
  # New entries keep the ID a previous target assigned (dev first, then prod), else take the next free one.
  id = if e["action"] == "new", do: e["id"] || next_id, else: e["id"]

  attrs =
    (e["attrs"] || %{})
    |> Map.put("id", id)
    |> Map.put_new("checked_on", today)
    |> then(&if(e["action"] == "new", do: Map.put_new(&1, "published", true), else: &1))
    |> then(&if(venue, do: Map.put_new(&1, "venue_id", venue.id), else: &1))

  result =
    cond do
      e["gym"] && is_nil(venue) -> {:error, "unknown gym #{e["gym"]}"}
      is_nil(id) -> {:error, "update without an id"}
      e["action"] == "new" and Repo.get(Listing, id) -> {:error, "id #{id} is already taken"}
      e["action"] == "update" and is_nil(Repo.get(Listing, id)) -> {:error, "no listing #{id} to update"}
      true ->
        case Import.put_listing(attrs, e["sessions"] || :preserve) do
          {:ok, l} -> {:ok, l}
          {:error, cs} -> {:error, inspect(Ecto.Changeset.traverse_errors(cs, fn {m, _} -> m end))}
        end
    end

  {line, next_id} =
    case result do
      {:ok, l} ->
        {%{"ref" => e["ref"], "id" => l.id, "status" => "ok", "title" => l.title, "sessions" => length(l.occurrences)},
         max(next_id, l.id + 1)}

      {:error, why} ->
        {%{"ref" => e["ref"], "id" => id, "status" => "error", "error" => why}, next_id}
    end

  IO.puts("APPLIED " <> Jason.encode!(line))
  next_id
end)
