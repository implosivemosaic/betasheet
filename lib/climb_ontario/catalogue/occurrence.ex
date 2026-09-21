defmodule ClimbOntario.Catalogue.Occurrence do
  @moduledoc "A confirmed local session date. Null time/timezone is unknown, not inherited."
  use Ecto.Schema
  import Ecto.Changeset
  alias ClimbOntario.Catalogue.Listing

  schema "occurrences" do
    belongs_to :listing, Listing
    field :date, :date
    field :cohort, :string
    field :start_time, :time
    field :end_time, :time
    field :timezone, :string
    belongs_to :venue, ClimbOntario.Catalogue.Venue
    field :location_kind, :string, default: "inherit"
    field :offsite_name, :string
    field :offsite_address, :string
    field :offsite_city, :string
    field :offsite_lat, :float
    field :offsite_lng, :float
  end

  @doc "Deterministic chronological session order; unknown time sorts after known times."
  def sort_key(o) do
    seconds =
      if o.start_time, do: elem(Time.to_seconds_after_midnight(o.start_time), 0), else: 86_400

    {Date.to_gregorian_days(o.date), seconds, o.cohort, o.id}
  end

  @fields ~w(date cohort start_time end_time timezone venue_id location_kind offsite_name offsite_address offsite_city offsite_lat offsite_lng)a
  def fields, do: @fields

  def changeset(occurrence, attrs, listing) do
    cs =
      occurrence
      |> cast(attrs, @fields)
      |> put_change(:listing_id, listing.id)
      |> validate_required([:date, :location_kind])
      |> Listing.validate_times()
      |> Listing.validate_location(~w(inherit venue offsite unknown))
      |> foreign_key_constraint(:venue_id)
      |> foreign_key_constraint(:listing_id)

    cs =
      if get_field(cs, :location_kind) == "venue",
        do: validate_required(cs, [:venue_id]),
        else: cs

    cs =
      if get_field(cs, :venue_id) && get_field(cs, :location_kind) != "venue",
        do: add_error(cs, :venue_id, "requires location_kind venue"),
        else: cs

    cs =
      if get_field(cs, :cohort) && get_field(cs, :cohort) not in listing.cohorts,
        do: add_error(cs, :cohort, "must name one of the listing cohorts"),
        else: cs

    case get_field(cs, :date) do
      %Date{} = d ->
        if (listing.start_date && Date.compare(d, listing.start_date) == :lt) ||
             (listing.end_date && Date.compare(d, listing.end_date) == :gt) ||
             (listing.schedule_kind == "one_off" && d != listing.start_date),
           do: add_error(cs, :date, "is outside the listing bounds"),
           else: cs

      _ ->
        cs
    end
  end
end
