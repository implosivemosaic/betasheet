defmodule ClimbOntario.Catalogue.Occurrence do
  @moduledoc "A confirmed date a course class or recurring meetup happens."
  use Ecto.Schema

  schema "occurrences" do
    belongs_to :listing, ClimbOntario.Catalogue.Listing
    field :date, :date
  end
end
