defmodule ClimbOntario.Clock do
  @moduledoc "Local date for visitors. Everything in the catalogue is in Ontario."
  @tz "America/Toronto"
  def today, do: DateTime.now!(@tz) |> DateTime.to_date()
end
