defmodule ClimbOntario.Catalogue.Class do
  @moduledoc """
  One class inside a bundled listing, by the facts that set it apart: an age
  band, a level or stream, a format. Day and time are never stored here; they
  come from the class's sessions. `name` must match an entry in the listing's
  `cohorts`, which is what sessions are labelled with.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # Keyed by name so an identical reimport matches in place and is not a change.
  @primary_key {:name, :string, autogenerate: false}
  embedded_schema do
    field :ages, :string
    field :level, :string
    field :format, :string
  end

  def changeset(class, attrs) do
    class
    |> cast(attrs, [:name, :ages, :level, :format])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:ages, max: 40)
    |> validate_length(:level, max: 60)
    |> validate_length(:format, max: 60)
  end

  def blank?(nil), do: true
  def blank?(text) when is_binary(text), do: String.trim(text) == ""
end
