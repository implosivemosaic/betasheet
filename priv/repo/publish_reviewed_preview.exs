# Bounded preview publication: preserve research and hold known schema edge cases.
import Ecto.Query
alias ClimbOntario.{Repo, Catalogue.Import}
alias ClimbOntario.Catalogue.Listing
held = [27, 99, 279]
rows = Repo.all(from l in Listing, where: not l.published, order_by: l.id)
results = Enum.map(rows, fn l ->
  if l.id in held do
    %{id: l.id, result: "held", reason: "Unresolved schedule representation"}
  else
    case Import.publish(l.id) do
      {:ok, _} -> %{id: l.id, result: "published"}
      {:error, cs} -> %{id: l.id, result: "held", reason: inspect(cs.errors)}
    end
  end
end)
path = "/workspace/dot-files/knowledge/ontario-gyms/preview-publication-result.json"
File.write!(path, Jason.encode!(%{at: DateTime.utc_now(), results: results}, pretty: true))
IO.inspect(Enum.frequencies_by(results, & &1.result), label: "Publication")
Enum.each(Enum.filter(results, &(&1.result == "held")), &IO.inspect/1)
