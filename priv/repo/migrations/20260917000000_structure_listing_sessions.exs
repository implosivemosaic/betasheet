defmodule ClimbOntario.Repo.Migrations.StructureListingSessions do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :ocf, :boolean,
        check: %{name: "ocf_competition", expr: "ocf IS NULL OR kind = 'competition'"}

      add :cohorts, {:array, :string}, null: false, default: []
      add :timezone, :string

      add :location_kind, :string,
        null: false,
        default: "venue",
        check: %{
          name: "listing_location_kind",
          expr: "location_kind IN ('venue','offsite','unknown','multiple')"
        }

      add :offsite_city, :string

      add :recurrence, :string,
        check: %{
          name: "recurrence_allowed",
          expr: "recurrence IS NULL OR recurrence IN ('weekly','monthly')"
        }

      add :weekday, :integer,
        check: %{name: "weekday_allowed", expr: "weekday IS NULL OR weekday BETWEEN 1 AND 7"}

      add :month_week, :integer,
        check: %{
          name: "month_week_allowed",
          expr: "month_week IS NULL OR month_week IN (-1,1,2,3,4,5)"
        }

      add :catalogue_updated_on, :date
    end

    # Preserve existing evidence and timestamps. Only the reviewed non-OCF example is classified.
    execute "UPDATE listings SET location_kind = 'offsite' WHERE offsite_name IS NOT NULL",
            "SELECT 1"

    execute "UPDATE listings SET ocf = 0 WHERE id = 17 AND kind = 'competition'", "SELECT 1"

    drop unique_index(:occurrences, [:listing_id, :date])
    create index(:occurrences, [:listing_id, :date])

    alter table(:occurrences) do
      add :cohort, :string
      add :start_time, :time
      add :end_time, :time
      add :timezone, :string
      add :venue_id, references(:venues, on_delete: :restrict)

      add :location_kind, :string,
        null: false,
        default: "inherit",
        check: %{
          name: "occurrence_location_kind",
          expr: "location_kind IN ('inherit','venue','offsite','unknown')"
        }

      add :offsite_name, :string
      add :offsite_address, :string
      add :offsite_city, :string
      add :offsite_lat, :float
      add :offsite_lng, :float
    end

    execute """
            UPDATE occurrences SET
              start_time = (SELECT start_time FROM listings WHERE listings.id = occurrences.listing_id),
              end_time = (SELECT end_time FROM listings WHERE listings.id = occurrences.listing_id)
            """,
            "SELECT 1"
  end
end
