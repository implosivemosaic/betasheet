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
       interest_enabled: ClimbOntario.Interest.enabled?(),
       interest_form: nil,
       interest_saved: false,
       today: Clock.today(),
       place_names: Geo.place_names(),
       page_title: "What's on near you",
       visitor: if(connected?(socket), do: visitor(socket))
     )}
  end

  # Connect info is only readable during mount; keep what the counter needs.
  defp visitor(socket) do
    headers = Map.new(get_connect_info(socket, :x_headers) || [])
    peer = get_connect_info(socket, :peer_data)

    forwarded =
      (headers["x-forwarded-for"] || "") |> String.split(",") |> List.first() |> String.trim()

    %{
      ip:
        headers["fly-client-ip"] ||
          (if forwarded != "", do: forwarded) ||
          (peer && peer.address |> :inet.ntoa() |> to_string()),
      user_agent: get_connect_info(socket, :user_agent)
    }
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = Query.from_params(params, socket.assigns.today)
    all = Catalogue.search(query)
    limit = query.page * 20
    dated = Enum.take(all.dated, limit)
    ongoing = Enum.take(all.ongoing, max(limit - length(dated), 0))
    results = %{all | dated: dated, ongoing: ongoing}

    if socket.assigns.visitor, do: track(socket.assigns.visitor, query)

    {:noreply,
     assign(socket,
       query: query,
       results: results,
       shown: length(dated) + length(ongoing),
       near_error: query.near_text != nil and query.near == nil
     )}
  end

  # One count per search state, from real browsers only (connected sockets).
  defp track(visitor, query) do
    ClimbOntario.Stats.track(%{
      path: "/",
      query: query |> path() |> URI.parse() |> Map.get(:query),
      referrer: nil,
      ip: visitor.ip,
      user_agent: visitor.user_agent
    })
  end

  @impl true
  def handle_event("search", %{"near" => near}, socket) do
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | near_text: near}))}
  end

  def handle_event("keyword", %{"q" => text}, socket) do
    keyword = Query.from_params(%{"q" => text}, socket.assigns.today).keyword
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | keyword: keyword}))}
  end

  def handle_event("apply_filters", %{"group" => group} = params, socket) do
    values = Map.get(params, "values", []) |> List.wrap() |> Enum.join(",")
    q = socket.assigns.query

    parsed =
      Query.from_params(
        if(group == "when", do: Map.put(params, "days", values), else: %{group => values}),
        socket.assigns.today
      )

    query =
      case group do
        "kind" -> %{q | kinds: parsed.kinds}
        "for" -> %{q | audience: parsed.audience}
        "when" -> %{q | from: parsed.from, to: parsed.to, days: parsed.days}
      end

    {:noreply, push_patch(socket, to: path(query))}
  end

  def handle_event("radius", %{"km" => km}, socket) do
    radius = Query.from_params(%{"km" => km}, socket.assigns.today).radius_km
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | radius_km: radius}))}
  end

  def handle_event("located", %{"lat" => lat, "lng" => lng}, socket)
      when is_number(lat) and is_number(lng) do
    %{label: label} = Geo.nearest(lat, lng)
    {:noreply, push_patch(socket, to: path(%{socket.assigns.query | near_text: label}))}
  end

  def handle_event("located", _, socket), do: {:noreply, socket}

  def handle_event("interest_open", _, socket) do
    q = socket.assigns.query

    form =
      to_form(
        ClimbOntario.Interest.changeset(%{
          location: q.near_text || "",
          radius_km: q.radius_km,
          kinds: q.kinds,
          audience: q.audience
        }),
        as: :interest
      )

    {:noreply, assign(socket, interest_form: form, interest_saved: false)}
  end

  def handle_event("interest_save", %{"interest" => attrs}, socket) do
    case ClimbOntario.Interest.save(attrs) do
      :ok ->
        {:noreply, assign(socket, interest_saved: true, interest_form: nil)}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply, assign(socket, interest_form: to_form(cs, as: :interest))}

      {:error, :disabled} ->
        {:noreply, socket}
    end
  end

  # Every filter/location link resets depth; only Load more preserves/increases it.
  defp path(query), do: depth_path(%{query | page: 1})
  defp depth_path(query), do: ~p"/?#{Query.to_params(query)}"

  defp active_filters(q) do
    location =
      if q.near_text || q.radius_km != Query.default_km(),
        do: [
          {"#{q.near_text || "Distance"} · #{q.radius_km} km", "Remove location and distance",
           %{q | near_text: nil, radius_km: Query.default_km()}}
        ],
        else: []

    kinds =
      Enum.map(
        q.kinds,
        &{Format.kind_label(&1), "Remove event type #{Format.kind_label(&1)}",
         %{q | kinds: List.delete(q.kinds, &1)}}
      )

    audience =
      Enum.map(
        q.audience,
        &{Format.audience_label(&1), "Remove audience #{Format.audience_label(&1)}",
         %{q | audience: List.delete(q.audience, &1)}}
      )

    time =
      if q.from || q.to,
        do: [
          {"#{q.from || "Today"} – #{q.to || "Onward"}", "Remove date range",
           %{q | from: nil, to: nil}}
        ],
        else: []

    days =
      if q.days != [],
        do: [
          {Enum.map_join(q.days, ", ", &Enum.at(~w(Mon Tue Wed Thu Fri Sat Sun), &1 - 1)),
           "Remove weekdays", %{q | days: []}}
        ],
        else: []

    keyword =
      if q.keyword, do: [{q.keyword, "Remove keyword search", %{q | keyword: nil}}], else: []

    keyword ++ location ++ kinds ++ time ++ days ++ audience
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="pt-3 sm:pt-8">
        <h1 class="text-3xl sm:text-5xl font-extrabold tracking-tight text-balance leading-[1.05]">
          Find your next <span class="squiggle">climb.</span>
        </h1>

        <form id="keyword-search" phx-change="keyword" phx-submit="keyword" class="mt-3">
          <label for="keyword" class="sr-only">What are you looking for?</label>
          <input
            id="keyword"
            name="q"
            type="search"
            value={@query.keyword}
            maxlength="100"
            phx-debounce="300"
            placeholder="What are you looking for?"
            class="input w-full"
          />
        </form>
        <h2 id="location-label" class="mt-4 text-sm font-semibold">Location</h2>
        <div class="flex flex-wrap gap-2 items-end">
          <form
            phx-submit="search"
            class="mt-2 flex gap-1 min-w-0 flex-1 basis-44"
            role="search"
            aria-labelledby="location-label"
          >
            <label class="input min-w-0 flex-1 items-center gap-1 rounded-field pr-1">
              <.icon name="hero-map-pin" class="size-5 shrink-0 text-base-content/50" />
              <input
                type="search"
                name="near"
                value={@query.near_text}
                list="places"
                placeholder="City / postal"
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
            <button type="submit" class="btn btn-primary rounded-field px-3">Go</button>
          </form>

          <form phx-change="radius" id="distance-filter" class="shrink-0">
            <label for="distance" class="sr-only">Distance</label>
            <select id="distance" name="km" class="select min-h-11 w-auto" aria-label="Distance">
              <option
                :for={km <- Enum.sort(Enum.uniq([10, 25, 40, 100, 150, 250, 500, @query.radius_km]))}
                value={km}
                selected={km == @query.radius_km}
              >
                {km} km
              </option>
            </select>
          </form>
        </div>
        <p :if={@near_error} class="mt-2 text-sm text-error">
          We couldn't place “{@query.near_text}”. Try a city or town name, or postal code.
        </p>
      </section>

      <nav
        id="filter-sheets"
        phx-hook="FilterSheets"
        class="mt-3 grid grid-cols-3 gap-2"
        aria-label="Filters"
      >
        <div :for={
          {group, label, options, selected} <- [
            {"kind", "Event type", Enum.map(Listing.discovery_kinds(), &{&1, Format.kind_label(&1)}),
             @query.kinds},
            {"when", "When",
             Enum.with_index(~w(Mon Tue Wed Thu Fri Sat Sun), 1)
             |> Enum.map(fn {label, n} -> {n, label} end), @query.days},
            {"for", "Audience", Enum.map(Listing.audiences(), &{&1, Format.audience_label(&1)}),
             @query.audience}
          ]
        }>
          <button
            type="button"
            data-open={"sheet-#{group}"}
            aria-haspopup="dialog"
            aria-controls={"sheet-#{group}"}
            class={[
              "btn w-full px-2 text-xs",
              if(selected != [] or (group == "when" and Query.dated_filter?(@query)),
                do: "btn-primary",
                else: "btn-outline"
              )
            ]}
          >
            {label} {if group == "when",
              do: if(Query.dated_filter?(@query), do: "Selected", else: "Anytime"),
              else: if(selected != [], do: "(#{length(selected)})", else: "All")}
          </button>
          <dialog id={"sheet-#{group}"} class="filter-sheet" aria-labelledby={"sheet-label-#{group}"}>
            <form phx-submit="apply_filters" id={"filter-form-#{group}"}>
              <input type="hidden" name="group" value={group} />
              <div class="flex items-center justify-between gap-3">
                <h2 id={"sheet-label-#{group}"} class="text-lg font-bold">{label}</h2>
                <button
                  type="button"
                  data-close
                  class="btn btn-ghost"
                  aria-label={"Close #{label} without applying"}
                >Close</button>
              </div>
              <p class="text-sm text-base-content/70">
                Choose, then Apply. Cancel keeps your current filters.
              </p>
              <div :if={group == "when"} class="mt-3 space-y-2">
                <div class="flex gap-2">
                  <label class="flex-1 min-w-0">From<input
                    type="date"
                    name="from"
                    value={@query.from}
                    class="input w-full"
                  /></label>
                  <label class="flex-1 min-w-0">To<input
                    type="date"
                    name="to"
                    value={@query.to}
                    class="input w-full"
                  /></label>
                </div>
                <p class="text-xs">
                  Upcoming dates only. Invalid or reversed ranges reset to Anytime; weekdays stay selected.
                </p>
                <div class="grid grid-cols-2 gap-2 when-shortcuts">
                  <button
                    :for={{key, text} <- [{"weekend", "This weekend"}, {"week", "Next 7 days"}]}
                    type="button"
                    class="btn min-h-11 h-11 w-full px-2 text-sm"
                    data-range-from={elem(Catalogue.window(key, @today), 0)}
                    data-range-to={elem(Catalogue.window(key, @today), 1)}
                  >{text}</button>
                </div>
              </div>
              <div
                :if={group == "when"}
                class="weekday-row my-3"
                role="group"
                aria-label="Days of the week"
              >
                <label :for={{value, _text} <- options} class="weekday-toggle">
                  <input
                    type="checkbox"
                    name="values[]"
                    value={value}
                    checked={value in selected}
                    aria-label={
                      Enum.at(~w(Monday Tuesday Wednesday Thursday Friday Saturday Sunday), value - 1)
                    }
                  />
                  <span aria-hidden="true">{Enum.at(~w(M T W T F S S), value - 1)}</span>
                </label>
              </div>
              <div :if={group != "when"} class="my-3 grid gap-2">
                <label
                  :for={{value, text} <- options}
                  class="flex items-center gap-3 min-h-11 rounded-field bg-base-200 px-3"
                >
                  <input
                    type="checkbox"
                    name="values[]"
                    value={value}
                    checked={value in selected}
                    class="checkbox checkbox-primary"
                  />
                  {text}
                </label>
              </div>
              <div class="flex gap-2">
                <button type="button" data-close class="btn flex-1">Cancel</button>
                <button type="submit" class="btn btn-primary flex-1">Apply</button>
              </div>
            </form>
          </dialog>
        </div>
      </nav>

      <section
        :if={@interest_enabled}
        class="mt-5 rounded-box border border-base-300 p-4"
        id="interest"
      >
        <button phx-click="interest_open" class="btn btn-outline btn-sm">Get updates like these</button>
        <p class="mt-2 text-sm text-base-content/70">
          Preview: interest only. Updates are not sending yet.
        </p>
        <p :if={@interest_saved} role="status" class="mt-3 font-medium">
          Interest saved. No emails sent. This is not a subscription.
        </p>
        <.form
          :if={@interest_form}
          for={@interest_form}
          id="interest-form"
          phx-submit="interest_save"
          class="mt-4 space-y-3"
        >
          <.input
            field={@interest_form[:location]}
            label="City or postal code (blank means all Ontario)"
            list="places"
          />
          <.input
            field={@interest_form[:radius_km]}
            type="number"
            min="1"
            max="500"
            label="Radius (km)"
          />
          <.input
            field={@interest_form[:kinds]}
            type="select"
            multiple
            label="Kinds (none means all)"
            options={Enum.map(Listing.discovery_kinds(), &{Format.kind_label(&1), &1})}
          />
          <.input
            field={@interest_form[:audience]}
            type="select"
            multiple
            label="Who it's for (none means everyone)"
            options={Enum.map(Listing.audiences(), &{Format.audience_label(&1), &1})}
          />
          <.input
            field={@interest_form[:email]}
            type="email"
            label="Email"
            required
            autocomplete="email"
          />
          <.input
            field={@interest_form[:consent]}
            type="checkbox"
            label="Save my email and these preferences for this private preview's interest research. No emails will be sent."
          />
          <button class="btn btn-primary" type="submit" phx-disable-with="Saving…">Save interest</button>
        </.form>
      </section>

      <section
        :if={active_filters(@query) != []}
        id="active-filters"
        aria-labelledby="active-label"
        class="mt-4 rounded-box bg-base-200 p-3"
      >
        <h2 id="active-label" class="text-sm font-semibold">Active filters</h2>
        <div class="mt-2 flex flex-wrap gap-2">
          <.link
            :for={{label, accessible, query} <- active_filters(@query)}
            patch={path(query)}
            replace
            aria-label={accessible}
            class="chip min-h-11"
          >{label} <span aria-hidden="true">×</span></.link>
          <.link
            patch={path(%Query{})}
            replace
            class="btn btn-ghost min-h-11"
            aria-label="Clear all filters"
          >Clear all</.link>
        </div>
      </section>

      <section class="mt-5" id="results">
        <p id="result-count" class="mb-3 text-sm text-base-content/70" role="status">
          Showing {@shown} of {@results.total} listings
        </p>
        <div
          :if={@results.total == 0}
          class="rounded-box border border-dashed border-base-300 p-8 text-center"
        >
          <p class="text-lg font-medium">Nothing here yet.</p>
          <p class="mt-1 text-sm text-base-content/70">
            Try a wider area, a different time window, or fewer filters.
          </p>
          <div class="mt-4 flex flex-wrap justify-center gap-2">
            <.link
              :if={@query.near}
              patch={path(%{@query | radius_km: 150})}
              replace
              class="btn btn-sm"
            >Look within 150 km</.link>
            <.link patch={path(%Query{})} replace class="btn btn-sm btn-ghost">Clear all filters</.link>
          </div>
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

        <.link
          :if={@shown < @results.total and @query.page < 50}
          id="load-more"
          patch={depth_path(%{@query | page: @query.page + 1})}
          replace
          class="btn btn-outline mt-5 w-full sm:w-auto"
        >Load more</.link>
      </section>
    </Layouts.app>
    """
  end
end
