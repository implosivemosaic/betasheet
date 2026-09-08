defmodule ClimbOntario.Catalogue.Listing do
  @moduledoc """
  One curated public listing. The columns are the data format; see the migration for
  what each means. `Import.changeset/2` is the only write path.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(competition social class camp)
  @schedule_kinds ~w(one_off multi_day course recurring unscheduled)
  @link_kinds ~w(registration event gym)
  @confidences ~w(confirmed tentative check)
  @audiences ~w(youth adult family adaptive women queer)

  @primary_key {:id, :id, autogenerate: false}
  schema "listings" do
    belongs_to :venue, ClimbOntario.Catalogue.Venue
    field :title, :string
    field :kind, :string
    field :label, :string
    field :summary, :string
    field :schedule_kind, :string
    field :start_date, :date
    field :end_date, :date
    field :start_time, :time
    field :end_time, :time
    field :schedule_note, :string
    field :audience, {:array, :string}, default: []
    field :ages, :string
    field :link, :string
    field :link_kind, :string
    field :offsite_name, :string
    field :offsite_address, :string
    field :offsite_lat, :float
    field :offsite_lng, :float
    field :confidence, :string
    field :caveat, :string
    field :sources, {:array, :string}, default: []
    field :checked_on, :date
    field :published, :boolean, default: false
    has_many :occurrences, ClimbOntario.Catalogue.Occurrence
    field :distance_km, :float, virtual: true
    timestamps()
  end

  def kinds, do: @kinds
  def schedule_kinds, do: @schedule_kinds
  def link_kinds, do: @link_kinds
  def confidences, do: @confidences
  def audiences, do: @audiences

  @fields ~w(id venue_id title kind label summary schedule_kind start_date end_date start_time end_time
             schedule_note audience ages link link_kind offsite_name offsite_address
             offsite_lat offsite_lng confidence caveat sources checked_on published)a

  def changeset(listing, attrs) do
    listing
    |> cast(attrs, @fields)
    |> validate_required([:id, :venue_id, :title, :checked_on])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:schedule_kind, @schedule_kinds)
    |> validate_inclusion(:link_kind, @link_kinds)
    |> validate_inclusion(:confidence, @confidences)
    |> validate_subset(:audience, @audiences)
    |> validate_length(:summary, max: 240)
    |> validate_length(:caveat, max: 160)
    |> validate_schedule()
    |> validate_published()
    |> foreign_key_constraint(:venue_id)
  end

  defp validate_schedule(cs) do
    case get_field(cs, :schedule_kind) do
      "one_off" ->
        validate_required(cs, [:start_date])

      k when k in ["multi_day", "course"] ->
        cs |> validate_required([:start_date, :end_date]) |> validate_order()

      _ ->
        cs
    end
  end

  defp validate_order(cs) do
    with %Date{} = s <- get_field(cs, :start_date),
         %Date{} = e <- get_field(cs, :end_date),
         :gt <- Date.compare(s, e) do
      add_error(cs, :end_date, "is before start_date")
    else
      _ -> cs
    end
  end

  # Publishing is the judgment boundary: nothing appears until every judgment field is set.
  defp validate_published(cs) do
    if get_field(cs, :published) do
      validate_required(
        cs,
        [:kind, :label, :summary, :schedule_kind, :confidence, :link, :link_kind],
        message: "is required to publish"
      )
    else
      cs
    end
  end

  @doc "URL slug: research id, then the title."
  def slug(%__MODULE__{id: id, title: title}), do: "#{id}-#{slugify(title)}"

  def slugify(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
