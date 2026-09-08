defmodule ClimbOntario.Catalogue.Venue do
  @moduledoc "A place events happen at. One row per research gym; coordinates from priv/geo/gyms.json."
  use Ecto.Schema

  schema "venues" do
    field :source_gym_id, :integer
    field :slug, :string
    field :name, :string
    field :street_address, :string
    field :city, :string
    field :postal_code, :string
    field :website, :string
    field :lat, :float
    field :lng, :float
    field :verification, :string
    has_many :listings, ClimbOntario.Catalogue.Listing
    timestamps()
  end
end
