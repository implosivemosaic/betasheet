# Listing 7: the organizer's eligibility has an alternative route the record dropped.
# Source: https://www.aspireclimbing.com/whitby/anniversary-event — "Athletes must be 12+
# to compete OR be a member of a climbing competitive team / advanced climbing program."
case ClimbOntario.Catalogue.Import.put_listing(%{
       id: 7,
       ages: "Ages 12+, or members of a competitive team or advanced climbing program",
       summary: "80s-themed anniversary boulder scramble with peer judging. Open to climbers 12+, or younger members of a competitive team or advanced program."
     }) do
  {:ok, l} -> IO.puts("ok 7: #{l.ages}")
  {:error, cs} -> IO.inspect(cs.errors, label: "error 7")
end
