defmodule ClimbOntario.Repo.Migrations.CreateCatalogue do
  @moduledoc """
  The catalogue schema is the data format. Researchers write curated rows here directly;
  the app reads published rows and never interprets prose. Allowed values are enforced
  by CHECK constraints so a row that doesn't fit doesn't insert.
  """
  use Ecto.Migration

  def change do
    create table(:venues) do
      add :source_gym_id, :integer, null: false, comment: "gyms.id in the research database"
      add :slug, :string, null: false
      add :name, :string, null: false
      add :street_address, :string
      add :city, :string, null: false
      add :postal_code, :string
      add :website, :string
      add :lat, :float
      add :lng, :float
      timestamps()
    end

    create unique_index(:venues, [:source_gym_id])
    create unique_index(:venues, [:slug])

    # id is the research event id; it leads every public URL and never changes.
    create table(:listings, primary_key: false) do
      add :id, :integer, primary_key: true
      add :venue_id, references(:venues, on_delete: :restrict), null: false
      add :title, :string, null: false

      add :kind, :string,
        comment: "competition | social | class | camp",
        check: %{
          name: "kind_allowed",
          expr: "kind IS NULL OR kind IN ('competition','social','class','camp')"
        }

      add :label, :string, comment: "short badge text, e.g. OCF sanctioned, Meetup, Kids program"

      add :summary, :text,
        comment:
          "1-2 plain sentences: what it is and who it's for. No dates, no gym name, no prices, rules or booking conditions; those stay on the organizer's page"

      add :schedule_kind, :string,
        comment: "one_off | multi_day | course | recurring | unscheduled",
        check: %{
          name: "schedule_kind_allowed",
          expr:
            "schedule_kind IS NULL OR schedule_kind IN ('one_off','multi_day','course','recurring','unscheduled')"
        }

      add :start_date, :date, comment: "one_off: the date; multi_day/course: first day"

      add :end_date, :date,
        comment: "multi_day/course: last day; recurring: last known date, if the series ends"

      add :start_time, :time
      add :end_time, :time
      add :schedule_note, :string, comment: "human pattern, e.g. Last Friday of the month, 7-9 pm"

      add :audience, {:array, :string},
        null: false,
        default: [],
        comment: "subset of youth adult family adaptive women queer"

      add :ages, :string, comment: "e.g. Ages 6-12, Ages 16+, U11-U15"
      add :link, :string, comment: "the one place to send people"

      add :link_kind, :string,
        comment: "registration | event | gym",
        check: %{
          name: "link_kind_allowed",
          expr: "link_kind IS NULL OR link_kind IN ('registration','event','gym')"
        }

      add :offsite_name, :string, comment: "set when the event is not at the venue gym"
      add :offsite_address, :string
      add :offsite_lat, :float
      add :offsite_lng, :float

      add :confidence, :string,
        comment: "confirmed | tentative | check",
        check: %{
          name: "confidence_allowed",
          expr: "confidence IS NULL OR confidence IN ('confirmed','tentative','check')"
        }

      add :caveat, :string,
        comment:
          "only when omitting it would make OUR date, time or place misleading (e.g. venue TBA, date unconfirmed); surrounding logistics stay on the organizer's page"

      add :sources, {:array, :string}, null: false, default: []
      add :checked_on, :date, null: false, comment: "when the sources were last read"

      add :published, :boolean,
        null: false,
        default: false,
        comment: "false until every judgment field is filled and reviewed",
        check: %{
          name: "published_is_complete",
          expr:
            "published = 0 OR (kind IS NOT NULL AND label IS NOT NULL AND summary IS NOT NULL AND schedule_kind IS NOT NULL AND confidence IS NOT NULL AND link IS NOT NULL AND link_kind IS NOT NULL)"
        }

      timestamps()
    end

    create index(:listings, [:venue_id])
    create index(:listings, [:published, :kind, :start_date])

    # Confirmed dates a class or meetup actually happens. Date filters match these, never a rule.
    create table(:occurrences) do
      add :listing_id, references(:listings, on_delete: :delete_all), null: false
      add :date, :date, null: false
    end

    create unique_index(:occurrences, [:listing_id, :date])
  end
end
