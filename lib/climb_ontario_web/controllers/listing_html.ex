defmodule ClimbOntarioWeb.ListingHTML do
  use ClimbOntarioWeb, :html
  import ClimbOntarioWeb.ListingComponents
  alias ClimbOntarioWeb.Format

  embed_templates "listing_html/*"

  def where(%{offsite_name: name} = l) when is_binary(name),
    do: "#{name} · organized by #{l.venue.name}"

  def where(l), do: Format.venue_line(l.venue)

  def maps_url(%{offsite_name: name, offsite_lat: lat, offsite_lng: lng}) when is_binary(name) do
    if lat && lng, do: "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}", else: nil
  end

  def maps_url(%{venue: %{lat: lat, lng: lng}}) when is_float(lat) and is_float(lng),
    do: "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}"

  def maps_url(%{venue: v}),
    do:
      "https://www.google.com/maps/search/?api=1&query=" <>
        URI.encode_www_form("#{v.name} #{v.city} Ontario")

  def past?(%{schedule_kind: k, start_date: s, end_date: e}, today)
      when k in ~w(one_off multi_day course) do
    Date.compare(e || s, today) == :lt
  end

  def past?(%{end_date: %Date{} = e}, today), do: Date.compare(e, today) == :lt
  def past?(_, _), do: false

  @doc "Upcoming confirmed dates for courses and meetups, as one short line."
  def confirmed_dates(%{schedule_kind: k, occurrences: occ}, today)
      when k in ~w(course recurring) do
    upcoming =
      occ
      |> Enum.map(& &1.date)
      |> Enum.filter(&(Date.compare(&1, today) != :lt))
      |> Enum.sort(Date)

    case upcoming do
      [] ->
        nil

      dates ->
        "Confirmed dates: " <>
          Enum.map_join(Enum.take(dates, 8), ", ", &Format.date/1) <>
          if(length(dates) > 8, do: " …", else: "")
    end
  end

  def confirmed_dates(_, _), do: nil

  def host(url) do
    case URI.parse(url) do
      %{host: h} when is_binary(h) -> String.replace_prefix(h, "www.", "")
      _ -> url
    end
  end
end
