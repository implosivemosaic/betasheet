defmodule ClimbOntario.Geo do
  @moduledoc """
  Resolves what a person types ("Aurora", "L4G 1A1", "kitchener") to coordinates
  using bundled Ontario lookup tables. No network calls at runtime.
  """

  @fsa_path Application.app_dir(:climb_ontario, "priv/geo/ontario_fsa.json")
  @places_path Application.app_dir(:climb_ontario, "priv/geo/ontario_places.json")
  @external_resource @fsa_path
  @external_resource @places_path

  @fsa @fsa_path |> File.read!() |> Jason.decode!()
  @places @places_path |> File.read!() |> Jason.decode!()
  @place_index Map.new(@places, fn p -> {ClimbOntario.Geo.Normalize.key(p["name"]), p} end)
  @place_names Enum.map(@places, & &1["name"])

  @type point :: %{lat: float(), lng: float(), label: String.t()}

  @doc "All place names, for typeahead."
  def place_names, do: @place_names

  @doc "Resolve free text to a point. Postal codes win, then exact place, then prefix."
  @spec resolve(String.t() | nil) :: {:ok, point()} | :error
  def resolve(nil), do: :error

  def resolve(text) do
    key = ClimbOntario.Geo.Normalize.key(text)

    cond do
      key == "" -> :error
      fsa = fsa_match(key) -> {:ok, fsa}
      place = @place_index[key] -> {:ok, point(place)}
      place = prefix_match(key) -> {:ok, point(place)}
      true -> :error
    end
  end

  @doc "Nearest known place to a coordinate, for turning device location into a label."
  def nearest(lat, lng) do
    place = Enum.min_by(@places, fn p -> distance_km(lat, lng, p["lat"], p["lng"]) end)
    point(place)
  end

  @doc "Great-circle distance in km."
  def distance_km(lat1, lng1, lat2, lng2) do
    r = 6371.0
    dlat = rad(lat2 - lat1)
    dlng = rad(lng2 - lng1)

    a =
      :math.sin(dlat / 2) ** 2 +
        :math.cos(rad(lat1)) * :math.cos(rad(lat2)) * :math.sin(dlng / 2) ** 2

    2 * r * :math.asin(:math.sqrt(a))
  end

  defp fsa_match(key) do
    with [fsa] <- Regex.run(~r/^[klmnp]\d[a-z]/, key),
         %{} = hit <- @fsa[String.upcase(fsa)] do
      %{lat: hit["lat"], lng: hit["lng"], label: hit["name"]}
    else
      _ -> nil
    end
  end

  defp prefix_match(key) when byte_size(key) < 3, do: nil

  defp prefix_match(key) do
    @place_index
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, key) end)
    |> Enum.sort_by(fn {k, _} -> byte_size(k) end)
    |> List.first()
    |> case do
      {_, place} -> place
      nil -> nil
    end
  end

  defp point(place), do: %{lat: place["lat"], lng: place["lng"], label: place["name"]}
  defp rad(deg), do: deg * :math.pi() / 180
end
