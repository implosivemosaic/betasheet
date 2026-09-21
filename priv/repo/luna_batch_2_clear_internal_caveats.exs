alias ClimbOntario.Catalogue.Import
m = "/workspace/dot-files/knowledge/ontario-gyms/luna-conversion-assignments.json" |> File.read!() |> Jason.decode!() |> Map.fetch!("2")
allowed = (Enum.map(m["first_ten"], & &1["id"]) ++ m["remaining_ids"]) |> MapSet.new()
completed = [12,13,14,15,16,23,24,39,40,55,56,57,86,87,88,89,90,91,92,93,94,95,96,160,161,162,163,164,165,166,187,188,189,194,198,201,202,203,208,227,228,234,235,236,237,238,239,240,241,242,271,272,273,274,275,276]
unless length(completed) == 56 and Enum.all?(completed, &MapSet.member?(allowed, &1)), do: raise "completed ownership assertion failed"
Enum.each(completed, fn id ->
  case Import.put_listing(%{id: id, caveat: nil}, :preserve) do
    {:ok, l} -> IO.puts("cleared caveat #{l.id}")
    {:error, cs} -> IO.inspect(cs.errors); raise "caveat update failed #{id}"
  end
end)
IO.puts("cleared internal-only public caveats for 56 worker-2 remainder drafts")
