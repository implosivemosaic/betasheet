alias ClimbOntario.Catalogue.Import
case Import.put_listing(%{id: 127, caveat: "Session 2's Mountain Goat heading says Wednesday 18:30–20:00, while its dated rows are Thursdays; displayed sessions retain the dated Thursday evidence."}) do
  {:ok, l} -> IO.puts("patched #{l.id} caveat; #{length(l.occurrences)} occurrences")
  {:error, c} -> IO.inspect(c); raise "patch failed"
end
