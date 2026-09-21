defmodule ClimbOntario.Repo.Migrations.CreatePageViews do
  use Ecto.Migration

  # First-party, cookie-free counter. No raw IP or user agent is stored: the
  # visitor column is a salted hash that rotates daily.
  def change do
    create table(:page_views) do
      add :day, :date, null: false
      add :path, :string, null: false
      add :query, :string
      add :referrer, :string
      add :visitor, :string, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:page_views, [:day])
    create index(:page_views, [:day, :path])
  end
end
