defmodule ClimbOntario.Repo.Migrations.CreateCatalogue do
  use Ecto.Migration

  def change do
    create table(:venues) do
      add :source_gym_id, :integer, null: false
      add :slug, :string, null: false
      add :name, :string, null: false
      add :street_address, :string
      add :city, :string, null: false
      add :postal_code, :string
      add :website, :string
      add :lat, :float
      add :lng, :float
      add :verification, :string, null: false
      timestamps()
    end

    create unique_index(:venues, [:source_gym_id])
    create unique_index(:venues, [:slug])

    create table(:listings) do
      add :source_event_id, :integer, null: false
      add :venue_id, references(:venues, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :kind, :string, null: false
      add :subkind, :string, null: false
      add :schedule_kind, :string, null: false
      add :status, :string, null: false
      add :start_date, :date
      add :end_date, :date
      add :start_time, :time
      add :end_time, :time
      add :recurrence_text, :text
      add :price_text, :text
      add :price_short, :string
      add :price_note, :string
      add :schedule_note, :string
      add :ages, :string
      add :caveat, :string
      add :summary, :text, null: false
      add :details, :text
      add :audience, {:array, :string}, null: false, default: []
      add :skill, :string
      add :confidence, :string, null: false
      add :registration_state, :string, null: false
      add :venue_note, :string
      add :organizer_url, :string
      add :source_urls, {:array, :string}, null: false, default: []
      add :checked_at, :utc_datetime, null: false
      add :listed, :boolean, null: false, default: true
      timestamps()
    end

    create unique_index(:listings, [:source_event_id])
    create index(:listings, [:venue_id])
    create index(:listings, [:kind, :start_date])
  end
end
