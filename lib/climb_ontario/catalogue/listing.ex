defmodule ClimbOntario.Catalogue.Listing do
  @moduledoc """
  One curated public listing. The columns are the data format; see the migration for
  what each means. `Import.put_listing/2` is the curated write path.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(competition social class camp)
  @schedule_kinds ~w(one_off multi_day course recurring unscheduled)
  @link_kinds ~w(registration event gym)
  @confidences ~w(confirmed tentative check)
  @audiences ~w(youth adult family adaptive women queer)
  @bundled_by ~w(age level format day mixed)

  @primary_key {:id, :id, autogenerate: false}
  schema "listings" do
    belongs_to :venue, ClimbOntario.Catalogue.Venue
    field :title, :string
    field :kind, :string
    field :ocf, :boolean
    field :cohorts, {:array, :string}, default: []
    field :complete_cohorts, {:array, :string}, default: []
    field :bundled_by, :string
    embeds_many :classes, ClimbOntario.Catalogue.Class, on_replace: :delete
    field :timezone, :string
    field :location_kind, :string, default: "venue"
    field :offsite_city, :string
    field :recurrence, :string
    field :weekday, :integer
    field :month_week, :integer
    field :catalogue_updated_on, :date
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
    field :discovery_date, :date, virtual: true
    field :discovery_occurrence_id, :integer, virtual: true
    timestamps()
  end

  def kinds, do: @kinds
  def discovery_kinds, do: ~w(ocf competition social class camp)
  def discovery_kind(%{kind: "competition", ocf: true}), do: "ocf"
  def discovery_kind(l), do: l.kind
  def schedule_kinds, do: @schedule_kinds
  def link_kinds, do: @link_kinds
  def confidences, do: @confidences
  def audiences, do: @audiences
  def bundled_by, do: @bundled_by

  @fields ~w(id venue_id title kind label summary schedule_kind start_date end_date start_time end_time
             schedule_note audience ages link link_kind offsite_name offsite_address
             offsite_lat offsite_lng confidence caveat sources checked_on published
             ocf cohorts complete_cohorts bundled_by timezone location_kind offsite_city recurrence weekday month_week)a

  def changeset(listing, attrs) do
    listing
    |> cast(attrs, @fields)
    |> cast_embed(:classes)
    |> validate_required([
      :id,
      :venue_id,
      :title,
      :checked_on,
      :location_kind,
      :cohorts,
      :complete_cohorts,
      :audience,
      :sources
    ])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:schedule_kind, @schedule_kinds)
    |> validate_inclusion(:link_kind, @link_kinds)
    |> validate_inclusion(:confidence, @confidences)
    |> validate_subset(:audience, @audiences)
    |> validate_length(:summary, max: 240)
    |> validate_length(:caveat, max: 160)
    |> validate_url(:link)
    |> validate_change(:sources, fn :sources, urls ->
      if Enum.all?(urls, &valid_url?/1), do: [], else: [sources: "must contain HTTP(S) URLs"]
    end)
    |> validate_change(:cohorts, fn :cohorts, names ->
      if Enum.all?(names, &(is_binary(&1) and String.trim(&1) != "" and &1 != "__unnamed__")) and
           Enum.uniq(names) == names,
         do: [],
         else: [cohorts: "must contain unique nonblank names"]
    end)
    |> validate_complete_cohorts()
    |> validate_inclusion(:bundled_by, @bundled_by)
    |> validate_bundle()
    |> validate_location(~w(venue offsite unknown multiple))
    |> validate_times()
    |> validate_order()
    |> validate_recurrence()
    |> validate_schedule()
    |> validate_published()
    |> validate_ocf()
    |> foreign_key_constraint(:venue_id)
  end

  # A bundle is a listing with two or more named cohorts. New bundles, and any
  # change to a bundle's cohorts, must say what the classes are split by; each
  # class then carries the fact that distinguishes it. Records written before
  # this rule pass untouched until their cohorts change.
  defp validate_bundle(cs) do
    alias ClimbOntario.Catalogue.Class
    cohorts = get_field(cs, :cohorts) || []
    by = get_field(cs, :bundled_by)
    classes = get_field(cs, :classes) || []
    names = Enum.map(classes, & &1.name)
    bundle? = length(cohorts) > 1
    fresh? = is_nil(cs.data.id) or Map.has_key?(cs.changes, :cohorts)

    missing = fn field ->
      Enum.any?(classes, &Class.blank?(Map.get(&1, field)))
    end

    cond do
      by && not bundle? ->
        add_error(cs, :bundled_by, "needs at least two named cohorts")

      is_nil(by) and bundle? and fresh? ->
        add_error(cs, :bundled_by, "is required when a listing bundles several classes")

      Enum.uniq(names) != names or Enum.any?(names, &(&1 not in cohorts)) ->
        add_error(cs, :classes, "must name distinct classes from cohorts")

      by in ~w(age level format mixed) and cohorts -- names != [] ->
        add_error(cs, :classes, "must describe every class in cohorts")

      by == "age" and missing.(:ages) ->
        add_error(cs, :classes, "each class needs ages")

      by == "level" and missing.(:level) ->
        add_error(cs, :classes, "each class needs a level")

      by == "format" and missing.(:format) ->
        add_error(cs, :classes, "each class needs a format")

      by == "mixed" and
          Enum.any?(classes, &(Class.blank?(&1.ages) and Class.blank?(&1.level) and Class.blank?(&1.format))) ->
        add_error(cs, :classes, "each class needs ages, a level or a format")

      true ->
        cs
    end
  end

  # __unnamed__ identifies sessions whose cohort is nil; it is reserved from named cohorts.
  defp validate_complete_cohorts(cs) do
    complete = get_field(cs, :complete_cohorts) || []
    allowed = ["__unnamed__" | get_field(cs, :cohorts) || []]

    cond do
      Enum.uniq(complete) != complete or Enum.any?(complete, &(&1 not in allowed)) ->
        add_error(cs, :complete_cohorts, "must contain unique cohort names or __unnamed__")

      complete != [] and get_field(cs, :schedule_kind) != "course" ->
        add_error(cs, :complete_cohorts, "requires a finite course")

      true ->
        cs
    end
  end

  defp validate_schedule(cs) do
    case get_field(cs, :schedule_kind) do
      "one_off" ->
        validate_required(cs, [:start_date])

      k when k in ["multi_day", "course"] ->
        validate_required(cs, [:start_date, :end_date])

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

  defp validate_ocf(cs) do
    cond do
      get_field(cs, :kind) == "competition" and get_field(cs, :published) ->
        validate_required(cs, [:ocf])

      get_field(cs, :kind) != "competition" and not is_nil(get_field(cs, :ocf)) ->
        add_error(cs, :ocf, "is only for competitions")

      true ->
        cs
    end
  end

  defp validate_recurrence(cs) do
    cs =
      cs
      |> validate_inclusion(:recurrence, ~w(weekly monthly))
      |> validate_number(:weekday, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
      |> validate_inclusion(:month_week, [-1, 1, 2, 3, 4, 5])

    case get_field(cs, :recurrence) do
      nil ->
        if get_field(cs, :weekday) || get_field(cs, :month_week),
          do: add_error(cs, :recurrence, "is required with pattern fields"),
          else: cs

      pattern ->
        cs = validate_required(cs, [:weekday])
        cs = if pattern == "monthly", do: validate_required(cs, [:month_week]), else: cs

        cs =
          if pattern == "weekly" and get_field(cs, :month_week),
            do: add_error(cs, :month_week, "is only for monthly patterns"),
            else: cs

        if get_field(cs, :schedule_kind) in ~w(recurring course),
          do: cs,
          else: add_error(cs, :recurrence, "requires recurring or course schedule")
    end
  end

  @doc false
  def valid_url?(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host, userinfo: nil}} ->
        scheme in ["http", "https"] and is_binary(host) and host != "" and
          not Regex.match?(~r/[\s<>]/u, url)

      _ ->
        false
    end
  end

  def valid_url?(_), do: false

  def validate_url(cs, field) do
    value = get_field(cs, field)

    if is_nil(value) or valid_url?(value),
      do: cs,
      else: add_error(cs, field, "must be an absolute HTTP(S) URL")
  end

  def validate_times(cs) do
    cs =
      validate_change(cs, :timezone, fn :timezone, tz ->
        if Tzdata.zone_exists?(tz), do: [], else: [timezone: "must be an IANA timezone"]
      end)

    case {get_field(cs, :start_time), get_field(cs, :end_time)} do
      {nil, %Time{}} ->
        add_error(cs, :start_time, "is required with end_time")

      {%Time{} = s, %Time{} = e} ->
        if Time.compare(s, e) == :lt,
          do: cs,
          else: add_error(cs, :end_time, "must be after start_time on the same local date")

      _ ->
        cs
    end
  end

  def validate_location(cs, kinds) do
    cs =
      cs
      |> validate_inclusion(:location_kind, kinds)
      |> validate_number(:offsite_lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
      |> validate_number(:offsite_lng, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)

    cs =
      if is_nil(get_field(cs, :offsite_lat)) != is_nil(get_field(cs, :offsite_lng)),
        do: add_error(cs, :offsite_lat, "coordinates must be supplied together"),
        else: cs

    if get_field(cs, :location_kind) == "offsite",
      do: validate_required(cs, [:offsite_name]),
      else: cs
  end

  # Publishing is the judgment boundary: nothing appears until every judgment field is set.
  defp validate_published(cs) do
    if get_field(cs, :published) do
      cs =
        validate_required(
          cs,
          [:kind, :summary, :schedule_kind, :confidence, :link, :link_kind],
          message: "is required to publish"
        )

      case get_field(cs, :sources) do
        [_ | _] = sources ->
          if Enum.all?(sources, &valid_url?/1),
            do: cs,
            else: add_error(cs, :sources, "must contain HTTP(S) evidence URLs to publish")

        _ ->
          add_error(cs, :sources, "must include at least one evidence URL to publish")
      end
    else
      cs
    end
  end

  @doc "Actual location, separate from the organizing venue. Nil fields remain unknown."
  def location(l, occurrence \\ nil)
  def location(l, %{location_kind: "inherit"}), do: location(l)
  def location(_, occurrence) when not is_nil(occurrence), do: location(occurrence)
  def location(%{location_kind: "venue", venue: venue}, nil), do: venue

  def location(%{location_kind: "offsite"} = l, nil),
    do: %{
      name: l.offsite_name,
      city: l.offsite_city,
      street_address: l.offsite_address,
      lat: l.offsite_lat,
      lng: l.offsite_lng
    }

  def location(%{location_kind: "multiple"}, nil),
    do: %{
      name: "Multiple venues — see sessions",
      city: nil,
      street_address: nil,
      lat: nil,
      lng: nil
    }

  def location(_, nil),
    do: %{name: "Venue not announced", city: nil, street_address: nil, lat: nil, lng: nil}

  @doc "Public location summary reflects actual session venues when supplied."
  def display_location(%{occurrences: [_ | _] = occurrences} = l) do
    case occurrences
         |> Enum.map(&location(l, &1))
         |> Enum.uniq_by(&Map.take(&1, [:name, :city, :street_address, :lat, :lng])) do
      [place] -> place
      _ -> location(%{location_kind: "multiple"})
    end
  end

  def display_location(l), do: location(l)

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
