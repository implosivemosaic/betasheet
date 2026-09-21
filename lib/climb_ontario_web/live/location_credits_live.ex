defmodule ClimbOntarioWeb.LocationCreditsLive do
  use ClimbOntarioWeb, :live_view

  def mount(_, _, socket), do: {:ok, assign(socket, page_title: "Location data credits")}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <article class="py-6 space-y-4">
        <h1 class="text-2xl font-bold">Location data credits</h1>
        <p>
          Geocoding by <a class="link" href="https://opencagedata.com/">OpenCage</a>.
          © <a class="link" href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>,
          available under the <a class="link" href="https://opendatacommons.org/licenses/odbl/">Open Database License (ODbL)</a>.
        </p>
        <p>
          OpenCage aggregates data sources. Its API licence notice points to the <a
            class="link"
            href="https://opencagedata.com/credits"
          >full source and attribution guide</a>.
          Listed sources include <a class="link" href="https://www.geonames.org/">GeoNames</a>
          (CC BY), <a class="link" href="https://geocoder.ca/?services=1#postal">Geocoder.ca crowdsourced Canadian postal codes</a>,
          <a class="link" href="https://openaddresses.io/">OpenAddresses</a>
          (source-specific licences),
          <a class="link" href="https://quattroshapes.com/">Quattroshapes</a>
          (CC BY),
          Yahoo GeoPlanet and Twofishes (CC BY), Flickr Shapefiles (CC0), and
          <a class="link" href="https://www.naturalearthdata.com/">Natural Earth</a>
          (public domain).
          The API does not identify every contributing dataset per point; this credit is not a claim that each source contributed to every result.
        </p>
        <p>
          Our September 17, 2026 reviewed selection contains 54 gym points, 418 place names and
          524 postal prefixes. Coordinates and provider-formatted names come from OpenCage;
          reviewed place aliases support exact-name lookup. Results are selected and simplified from
          the provider responses, not surveyed entrances. Fifteen gym points and all postal-prefix
          points are approximate; distances are estimates. Approximate gym Map links search the
          organizer's street address instead of pinning a postal or neighbourhood centre.
          Event names and addresses remain organizer/research information.
        </p>
        <p>
          This is a limited public test. OpenCage permits permanent storage, including trial results;
          its free trial is for testing, and production use calls for a paid plan.
          The account's actual entitlement has not been confirmed.
          See <a class="link" href="https://opencagedata.com/pricing">plan policy</a>
          and <a class="link" href="https://opencagedata.com/terms">terms</a>.
          Credits do not establish licence clearance for every input address or source.
        </p>
        <a class="link" href="/">Back to listings</a>
      </article>
    </Layouts.app>
    """
  end
end
