defmodule ClimbOntarioWeb.ListingHTML do
  use ClimbOntarioWeb, :html
  import ClimbOntarioWeb.ListingComponents
  alias ClimbOntarioWeb.Format

  embed_templates "listing_html/*"

  def maps_url(%{lat: lat, lng: lng}) when is_float(lat) and is_float(lng),
    do: "https://www.google.com/maps/search/?api=1&query=#{lat},#{lng}"

  def maps_url(v),
    do:
      "https://www.google.com/maps/search/?api=1&query=" <>
        URI.encode_www_form("#{v.name} #{v.city} Ontario")

  def past?(%{schedule_kind: k, start_date: s, end_date: e}, today)
      when k in ~w(one_off multi_day course) do
    Date.compare(e || s, today) == :lt
  end

  def past?(_, _), do: false

  def host(url) do
    case URI.parse(url) do
      %{host: h} when is_binary(h) -> String.replace_prefix(h, "www.", "")
      _ -> url
    end
  end
end
