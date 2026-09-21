defmodule ClimbOntarioWeb.ListingHTML do
  use ClimbOntarioWeb, :html
  import ClimbOntarioWeb.ListingComponents
  alias ClimbOntarioWeb.Format
  alias ClimbOntario.Catalogue.Listing

  embed_templates "listing_html/*"

  def place_name(l), do: Listing.display_location(l).name
  def organized_by(l), do: if(Listing.display_location(l) == l.venue, do: nil, else: l.venue.name)

  def calendar_groups(l), do: ClimbOntarioWeb.ListingCalendar.groups(l)

  def calendar_ics_path(l, cohort) do
    path = ~p"/e/#{l.id}/calendar.ics"
    if cohort, do: path <> "?" <> URI.encode_query(cohort: cohort), else: path
  end

  def calendar_subscribe_url(l, cohort) do
    base = url(~p"/") |> URI.parse() |> Map.put(:scheme, "webcal") |> URI.to_string() |> String.trim_trailing("/")
    base <> calendar_ics_path(l, cohort)
  end

  def google_calendar_url(l, cohort) do
    ClimbOntarioWeb.ListingCalendar.google_url(l, cohort, url(~p"/e/#{Listing.slug(l)}"))
  end

  def bundled?(l), do: ClimbOntarioWeb.ClassSchedule.bundled?(l)
  def classes(l, today), do: ClimbOntarioWeb.ClassSchedule.classes(l, today)

  # A bundle has no single session count; its classes carry their own.
  def series_position(l, _today) when is_map(l) and l.cohorts != [] and length(l.cohorts) > 1, do: nil

  def series_position(l, today) do
    next =
      l.occurrences
      |> Enum.filter(&(Date.compare(&1.date, today) != :lt))
      |> Enum.min_by(&ClimbOntario.Catalogue.Occurrence.sort_key/1, fn -> nil end)

    next && ClimbOntario.Catalogue.Series.position(l, next)
  end

  def address(l) do
    place = Listing.display_location(l)

    Enum.join(
      [place.street_address || "Address not announced", place.city || "City not announced"],
      ", "
    )
  end

  def maps_url(l) do
    case Listing.display_location(l) do
      %ClimbOntario.Catalogue.Venue{} = venue ->
        metadata = ClimbOntario.Geo.gym_metadata(venue.source_gym_id)

        if metadata && metadata["precision"] == "USABLE" &&
             is_number(venue.lat) && is_number(venue.lng) do
          "https://www.google.com/maps/search/?api=1&query=#{venue.lat},#{venue.lng}"
        else
          if venue.street_address not in [nil, ""] do
            query =
              Enum.join(
                Enum.reject(
                  [venue.street_address, venue.city, "Ontario", venue.postal_code],
                  &is_nil/1
                ),
                ", "
              )

            "https://www.google.com/maps/search/?api=1&query=#{URI.encode_www_form(query)}"
          end
        end

      %{lat: lat, lng: lng} when is_number(lat) and is_number(lng) ->
        "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}"

      _ ->
        nil
    end
  end

  def past?(%{schedule_kind: k, start_date: s, end_date: e}, today)
      when k in ~w(one_off multi_day course) do
    Date.compare(e || s, today) == :lt
  end

  def past?(%{end_date: %Date{} = e}, today), do: Date.compare(e, today) == :lt
  def past?(_, _), do: false

  @doc "Structured bounds/pattern followed by confirmed sessions; no prose scheduling."
  def when_lines(l, today) do
    base =
      case l.schedule_kind do
        "one_off" ->
          [Format.date_with_year(l.start_date)]

        k when k in ~w(multi_day course) ->
          ["#{Format.date(l.start_date)} – #{Format.date_with_year(l.end_date)}"]

        "recurring" ->
          [Format.when_line(l, today)]

        _ ->
          ["Schedule not posted yet"]
      end

    details =
      if l.occurrences == [] and l.schedule_kind != "unscheduled",
        do: [Format.pattern(l) || Format.time_line(l)],
        else: [Format.pattern(l)]

    timezone = Format.common_timezone(l)
    base ++ details ++ [if(is_nil(Format.pattern(l)) or timezone != l.timezone, do: timezone)]
  end
end
