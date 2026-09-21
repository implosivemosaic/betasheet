defmodule ClimbOntario.GeoTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Geo

  test "postal codes resolve through the FSA table" do
    assert {:ok, %{label: label, lat: lat}} = Geo.resolve("L4G 1A1")
    assert label == "L4G, Canada"
    assert_in_delta lat, 43.99, 0.05
    assert {:ok, %{label: ^label}} = Geo.resolve("l4g")
  end

  test "place names resolve exactly, case and accent insensitive, without prefix guessing" do
    assert {:ok, %{label: "Kitchener"}} = Geo.resolve("kitchener")
    assert {:ok, %{label: "Toronto"}} = Geo.resolve("City of Toronto")
    assert :error = Geo.resolve("mississ")
    assert {:ok, %{label: "Mississauga"}} = Geo.resolve("Mississauga")
    assert {:ok, %{label: "Etobicoke"}} = Geo.resolve("Etobicoke")
  end

  test "nonsense is an error" do
    assert :error == Geo.resolve("zz")
    assert :error == Geo.resolve("")
    assert :error == Geo.resolve(nil)
  end

  test "all rejected names and postal prefixes fail honestly" do
    for name <- [
          "Cockburn Island",
          "Nipissing",
          "St. Joseph",
          "Armstrong",
          "James",
          "Lake of the Woods",
          "French River",
          "Greater Madawaska",
          "Hilton",
          "L8B",
          "M7R",
          "L8B 1A1",
          "M7R 1A1",
          "L4G nonsense"
        ] do
      assert :error == Geo.resolve(name), name
    end

    assert {:ok, _} = Geo.resolve("Hilton Beach")
    assert length(Geo.place_names()) == 418
  end

  test "gym provider and reviewed precision are retained" do
    assert %{"provider" => "OpenCage", "precision" => "USABLE_APPROX"} = Geo.gym_metadata(1)
    assert %{"precision" => "USABLE"} = Geo.gym_metadata(4)
  end

  test "distance" do
    assert_in_delta Geo.distance_km(43.65, -79.38, 45.42, -75.69), 352, 5
  end
end
