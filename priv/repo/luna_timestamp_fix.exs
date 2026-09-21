alias ClimbOntario.{Repo, Catalogue.Import}
alias ClimbOntario.Catalogue.Listing
for id <- [9, 10, 11] do
  l = Repo.get!(Listing, id) |> Map.from_struct()
  attrs = l |> Map.drop([:__meta__, :occurrences, :inserted_at, :updated_at]) |> Map.put(:checked_on, ~D[2026-09-07]) |> Map.put(:published, false)
  case Import.put_listing(attrs, :preserve) do
    {:ok, _} -> IO.puts("updated checked_on #{id}: 2026-09-07")
    {:error, e} -> IO.inspect(e); raise "timestamp update failed #{id}"
  end
end
