defmodule ClimbOntarioWeb.ListingHTML do
  use ClimbOntarioWeb, :html
  import ClimbOntarioWeb.ListingComponents
  alias ClimbOntarioWeb.Format

  embed_templates "listing_html/*"

  @doc "Name of the place, and the gym that organizes it when they differ."
  def place_name(%{offsite_name: name}) when is_binary(name), do: name
  def place_name(%{venue: v}), do: v.name

  def organized_by(%{offsite_name: name, venue: v}) when is_binary(name), do: v.name
  def organized_by(_), do: nil

  def address(%{offsite_name: name} = l) when is_binary(name),
    do: l.offsite_address || "Address on the organizer's page"

  def address(%{venue: v}),
    do: Enum.reject([v.street_address, v.city], &is_nil/1) |> Enum.join(", ")

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

  @doc "One or two short lines answering 'when?'. The first is the pattern, the second the span."
  def when_lines(%{schedule_kind: "one_off"} = l, _today),
    do: [join([Format.date_with_year(l.start_date), Format.time_range(l.start_time, l.end_time)])]

  def when_lines(%{schedule_kind: "multi_day"} = l, _today),
    do: [
      "#{Format.date(l.start_date)} – #{Format.date_with_year(l.end_date)}",
      Format.time_range(l.start_time, l.end_time)
    ]

  def when_lines(%{schedule_kind: "course"} = l, _today),
    do: [
      join([l.schedule_note, Format.time_range(l.start_time, l.end_time)], ", "),
      "#{Format.date(l.start_date)} – #{Format.date_with_year(l.end_date)}"
    ]

  def when_lines(%{schedule_kind: "recurring"} = l, today) do
    next = Format.next_date(l, today)

    [
      l.schedule_note || join(["Ongoing", Format.time_range(l.start_time, l.end_time)]),
      next && "Next #{Format.date_with_year(next)}"
    ]
  end

  def when_lines(_, _), do: ["Schedule not posted yet"]

  defp join(parts, sep \\ " · "), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(sep)
end
