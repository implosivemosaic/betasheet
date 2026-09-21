defmodule ClimbOntario.Stats.PageView do
  @moduledoc false
  use Ecto.Schema

  schema "page_views" do
    field :day, :date
    field :path, :string
    field :query, :string
    field :referrer, :string
    field :visitor, :string
    field :inserted_at, :utc_datetime
  end
end
