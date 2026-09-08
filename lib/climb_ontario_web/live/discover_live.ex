defmodule ClimbOntarioWeb.DiscoverLive do
  @moduledoc "The discovery screen: where are you, what kind of thing, when. Everything lives in the URL."
  use ClimbOntarioWeb, :live_view
  alias ClimbOntario.{Catalogue, Clock, Geo}
  alias ClimbOntario.Catalogue.{Listing, Query}
  alias ClimbOntarioWeb.Format
  import ClimbOntarioWeb.ListingComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       today: Clock.today(),
       place_names: Geo.place_names(),
       page_title: "What's on near you"
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = Query.from_params(params, socket.assigns.today)

    {:noreply,
     assign(socket,
       query: query,
       results: Catalogue.search(query),
       near_error: query.near_text != nil and query.near == nil
     )}
  end

  @impl true
  def handle_event("search", %{"near" => near}, socket) do
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | near_text: near}))}
  end

  def handle_event("located", %{"lat" => lat, "lng" => lng}, socket)
      when is_number(lat) and is_number(lng) do
    %{label: label} = Geo.nearest(lat, lng)
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | near_text: label}))}
  end

  def handle_event("located", _, socket), do: {:noreply, socket}

  defp path(query), do: ~p"/?#{Query.to_params(query)}"

  defp audience_summary([]), do: ""
  defp audience_summary(a), do: " · " <> Enum.map_join(a, ", ", &Format.audience_label/1)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="pt-3 sm:pt-8">
        <h1 class="text-3xl sm:text-5xl font-extrabold tracking-tight text-balance leading-[1.05]">
          What's on in Ontario <span class="squiggle">climbing</span>?
        </h1>
        <p class="mt-2 text-sm sm:text-base text-base-content/70">
          Comps, socials, classes and camps, near you.
        </p>

        <form phx-submit="search" class="mt-5 flex gap-2" role="search">
          <label class="input input-lg flex-1 items-center gap-2 rounded-field pr-1">
            <.icon name="hero-map-pin" class="size-5 shrink-0 text-base-content/50" />
            <input
              type="search"
              name="near"
              value={@query.near_text}
              list="places"
              placeholder="City or postal code"
              autocomplete="off"
              enterkeyhint="search"
              class="grow min-w-0"
              aria-label="City or postal code"
            />
            <datalist id="places"><option :for={n <- @place_names} value={n} /></datalist>
            <button
              type="button"
              id="locate"
              phx-hook="Locate"
              class="btn btn-ghost btn-sm btn-circle shrink-0"
              title="Use my location"
              aria-label="Use my location"
            >
              <.icon name="hero-viewfinder-circle" class="size-5" />
            </button>
          </label>
          <button type="submit" class="btn btn-lg btn-primary rounded-field px-5">Go</button>
        </form>

        <p :if={@near_error} class="mt-2 text-sm text-error">
          We couldn't place “{@query.near_text}”. Try a city or town name, or the first three characters of a postal code.
        </p>
        <p :if={@query.near} class="mt-2 text-sm text-base-content/70">
          Within {@query.radius_km} km of
          <span class="font-medium text-base-content">{@query.near.label}</span>
          <span :if={@query.radius_km < 100}> · <.link
            patch={path(%{@query | radius_km: 100})}
            replace
            class="link"
          >widen to 100 km</.link></span>
          ·
          <.link
            patch={path(%{@query | near_text: nil, radius_km: Query.default_km()})}
            replace
            class="link"
          >clear</.link>
        </p>
      </section>

      <nav class="mt-4 space-y-2" aria-label="Filters">
        <div class="flex flex-wrap gap-2">
          <.chip
            :for={k <- Listing.kinds()}
            patch={path(Query.toggle_kind(@query, k))}
            active={k in @query.kinds}
            kind={k}
          >
            {Format.kind_label(k)}
          </.chip>
        </div>
        <div class="flex flex-wrap gap-2">
          <.chip :for={w <- Query.whens()} patch={path(%{@query | when: w})} active={@query.when == w}>
            {Format.when_label(w)}
          </.chip>
        </div>
        <details class="text-sm" open={@query.audience != []}>
          <summary class="cursor-pointer select-none text-base-content/70">
            Who it's for{audience_summary(@query.audience)}
          </summary>
          <div class="mt-2 flex flex-wrap gap-2">
            <.chip
              :for={a <- ~w(youth adult family adaptive)}
              patch={path(Query.toggle_audience(@query, a))}
              active={a in @query.audience}
            >
              {Format.audience_label(a)}
            </.chip>
          </div>
        </details>
      </nav>

      <section class="mt-5" id="results">
        <div
          :if={@results.total == 0}
          class="rounded-box border border-dashed border-base-300 p-8 text-center"
        >
          <p class="text-lg font-medium">Nothing here yet.</p>
          <p class="mt-1 text-sm text-base-content/70">
            Try a wider area, a different time window, or fewer filters.
          </p>
          <.link
            :if={@query.near}
            patch={path(%{@query | radius_km: 150})}
            replace
            class="btn btn-sm mt-4"
          >Look within 150 km</.link>
        </div>

        <div :if={@results.dated != []}>
          <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
            Coming up · {length(@results.dated)}
          </h2>
          <div id="dated" class="mt-2 grid gap-3 fade-up">
            <.listing_card :for={l <- @results.dated} listing={l} today={@today} />
          </div>
        </div>

        <div :if={@results.ongoing != []} class="mt-8">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
            Ongoing &amp; recurring · {length(@results.ongoing)}
          </h2>
          <div id="ongoing" class="mt-2 grid gap-3 fade-up">
            <.listing_card :for={l <- @results.ongoing} listing={l} today={@today} />
          </div>
        </div>

        <p class="mt-8 text-xs text-base-content/60">
          <%= if @query.unscheduled do %>
            Showing programs whose schedule isn't posted yet.
            <.link patch={path(%{@query | unscheduled: false})} replace class="link">Hide them</.link>
          <% else %>
            Some programs haven't posted a schedule yet.
            <.link patch={path(%{@query | unscheduled: true})} replace class="link">Show them too</.link>
          <% end %>
        </p>
      </section>
    </Layouts.app>
    """
  end
end
