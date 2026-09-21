defmodule ClimbOntarioWeb.ListingHTMLTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Catalogue.Venue
  alias ClimbOntarioWeb.ListingHTML

  test "approximate gym points search organizer address, never the area centroid" do
    for id <- 1..54 do
      metadata = ClimbOntario.Geo.gym_metadata(id)

      venue = %Venue{
        source_gym_id: id,
        street_address: "186 Spadina Ave. Unit 1A",
        city: "Toronto",
        postal_code: "M5T 3B2",
        lat: metadata["lat"],
        lng: metadata["lng"]
      }

      listing = %{venue: venue, location_kind: "venue", occurrences: []}
      url = ListingHTML.maps_url(listing)

      if metadata["precision"] == "USABLE_APPROX" do
        assert url =~ "186+Spadina"
        refute url =~ to_string(venue.lat)
      else
        assert url =~ "#{venue.lat},#{venue.lng}"
      end
    end
  end
end
