defmodule ClimbOntario.GeoTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Geo

  test "postal codes resolve through the FSA table" do
    assert {:ok, %{label: "Aurora", lat: lat}} = Geo.resolve("L4G 1A1")
    assert_in_delta lat, 43.99, 0.05
    assert {:ok, %{label: "Aurora"}} = Geo.resolve("l4g")
  end

  test "place names resolve exactly, case and accent insensitive, then by prefix" do
    assert {:ok, %{label: "Kitchener"}} = Geo.resolve("kitchener")
    assert {:ok, %{label: "Toronto"}} = Geo.resolve("City of Toronto")
    assert {:ok, %{label: "Mississauga"}} = Geo.resolve("mississ")
    assert {:ok, %{label: "Etobicoke"}} = Geo.resolve("Etobicoke")
  end

  test "nonsense is an error" do
    assert :error == Geo.resolve("zz")
    assert :error == Geo.resolve("")
    assert :error == Geo.resolve(nil)
  end

  test "distance" do
    assert_in_delta Geo.distance_km(43.65, -79.38, 45.42, -75.69), 352, 5
  end
end
