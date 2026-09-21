defmodule ClimbOntario.Catalogue.Series do
  @moduledoc "Position of a session among the recorded sessions for its course cohort."
  alias ClimbOntario.Catalogue.Occurrence

  def position(
        %{id: listing_id, schedule_kind: "course"} = listing,
        %{id: id, listing_id: listing_id, cohort: cohort}
      )
      when not is_nil(id) do
    sessions =
      listing.occurrences
      |> Enum.filter(&(&1.cohort == cohort and &1.listing_id == listing.id))
      |> Enum.sort_by(&Occurrence.sort_key/1)

    case Enum.find_index(sessions, &(&1.id == id)) do
      nil -> nil
      index -> %{index: index + 1, total: length(sessions)}
    end
  end

  def position(_, _), do: nil
end
