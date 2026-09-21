import Ecto.Query

a = File.read!("/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json") |> Jason.decode!() |> Map.fetch!("2")
ids = Enum.map(a["first_ten"], & &1["id"]) ++ a["remaining_ids"]
r = ClimbOntario.Catalogue.ResearchSource.load()
re = Map.new(r.events, &{&1["id"], &1})
ls = ClimbOntario.Repo.all(ClimbOntario.Catalogue.Listing) |> Map.new(&{&1.id, &1})
rows = Enum.map(ids, fn id ->
  l = ls[id]
  e = re[id]
  os = ClimbOntario.Repo.all(from(o in ClimbOntario.Catalogue.Occurrence, where: o.listing_id == ^id))
  keys = Enum.map(os, &{&1.date, &1.cohort, &1.start_time, &1.end_time})
  duplicate = length(keys) != length(Enum.uniq(keys))
  lower = Enum.all?(os, fn o -> is_nil(l.start_date) or Date.compare(o.date, l.start_date) != :lt end)
  upper = Enum.all?(os, fn o -> is_nil(l.end_date) or Date.compare(o.date, l.end_date) != :gt end)
  {id, not is_nil(l), l && l.venue_id == e["gym_id"], l && l.published == false,
   l && is_list(l.sources) and length(l.sources) > 0,
   l && l.checked_on == Date.from_iso8601!(String.slice(e["checked_at"], 0, 10)),
   duplicate, not (lower and upper), length(os)}
end)
checks = fn i -> Enum.filter(rows, &(not elem(&1, i))) end
IO.inspect(%{total: length(ids), missing: checks.(1), wrong_owner: checks.(2), published: checks.(3), no_sources: checks.(4), timestamp_mismatch: checks.(5), duplicate_occurrences: Enum.filter(rows, &elem(&1, 6)), out_of_bounds: Enum.filter(rows, &elem(&1, 7)), occurrences: Enum.sum(Enum.map(rows, &elem(&1, 8)))})
