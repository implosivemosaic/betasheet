defmodule ClimbOntario.Catalogue.Listing do
  @moduledoc """
  A public-facing event or program, curated from one research event row.

  kind: competition | social | class | camp
  schedule_kind: one_off | multi_day | course | recurring | unscheduled
  confidence: confirmed | tentative | check  (check = source had conflicts; confirm with organizer)
  registration_state: open | full | opens_later | unknown
  """
  use Ecto.Schema

  @kinds ~w(competition social class camp)
  @schedule_kinds ~w(one_off multi_day course recurring unscheduled)

  schema "listings" do
    field :source_event_id, :integer
    belongs_to :venue, ClimbOntario.Catalogue.Venue
    field :slug, :string
    field :title, :string
    field :kind, :string
    field :subkind, :string
    field :schedule_kind, :string
    field :status, :string
    field :start_date, :date
    field :end_date, :date
    field :start_time, :time
    field :end_time, :time
    field :recurrence_text, :string
    field :price_text, :string
    field :price_short, :string
    field :price_note, :string
    field :schedule_note, :string
    field :ages, :string
    field :caveat, :string
    field :summary, :string
    field :details, :string
    field :audience, {:array, :string}, default: []
    field :skill, :string
    field :confidence, :string
    field :registration_state, :string
    field :venue_note, :string
    field :organizer_url, :string
    field :link_kind, :string
    field :source_urls, {:array, :string}, default: []
    field :checked_at, :utc_datetime
    field :listed, :boolean, default: true
    field :distance_km, :float, virtual: true
    timestamps()
  end

  def kinds, do: @kinds
  def schedule_kinds, do: @schedule_kinds
end
