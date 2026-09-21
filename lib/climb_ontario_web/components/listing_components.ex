defmodule ClimbOntarioWeb.ListingComponents do
  @moduledoc "Cards, badges and filter chips shared by the discovery page and event pages."
  use ClimbOntarioWeb, :html
  alias ClimbOntarioWeb.Format

  attr :listing, :map, required: true
  attr :today, Date, required: true

  def listing_card(assigns) do
    date = Format.card_date(assigns.listing, assigns.today)

    session = Format.card_session(assigns.listing, date)

    place =
      if session,
        do: ClimbOntario.Catalogue.Listing.location(assigns.listing, session),
        else: ClimbOntario.Catalogue.Listing.display_location(assigns.listing)

    gym =
      if match?(%ClimbOntario.Catalogue.Venue{}, place), do: place, else: assigns.listing.venue

    assigns =
      assign(assigns,
        card_date: date,
        session: session,
        place: place,
        gym: gym,
        series: assigns.listing.schedule_kind in ~w(course recurring),
        classes:
          if(ClimbOntarioWeb.ClassSchedule.bundled?(assigns.listing),
            do: length(assigns.listing.cohorts)
          ),
        position:
          if(ClimbOntarioWeb.ClassSchedule.bundled?(assigns.listing),
            do: nil,
            else: ClimbOntario.Catalogue.Series.position(assigns.listing, session)
          )
      )

    ~H"""
    <article class={["card-lift listing-card relative rounded-box", @series && "series-card"]}>
      <span :if={@series} class="sr-only">Series</span>
      <div class="relative overflow-hidden rounded-box bg-base-100 border border-base-300 p-4 shadow-sm">
        <.rock kind={@listing.kind} />
        <div class="relative">
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1 text-sm">
            <time
              :if={@card_date}
              class="dateline font-bold"
              datetime={Date.to_iso8601(@card_date)}
              data-date={Date.to_iso8601(@card_date)}
              aria-label={Format.date_with_year(@card_date)}
            >{Format.date(@card_date)}</time>
            <span :if={!@card_date} class="dateline font-bold text-base-content/50" aria-label="Dates not confirmed">
              Dates TBA
            </span>
            <.kind_badge listing={@listing} />
            <span :if={@classes} class="series-position text-xs font-bold">{@classes} classes</span>
            <span :if={!@classes && !@position && Format.series_label(@listing)} class="series-position text-xs font-bold">
              {Format.series_label(@listing)}
            </span>
            <details :if={@position} class="series-position text-xs open:basis-full">
              <summary
                class="inline-flex cursor-pointer list-none items-center gap-1 font-bold"
                aria-label={"Session #{@position.index} of about #{@position.total}"}
              >
                {@position.index} of ~{@position.total}
                <.icon name="hero-information-circle" class="size-3.5" />
              </summary>
              <p class="mt-1 font-normal text-base-content/70">
                We estimate {@position.total} sessions based on our search. Always check with the gym to verify.
              </p>
            </details>
          </div>
          <h3 class="mt-2 text-lg font-bold leading-snug tracking-tight">
            <a href={~p"/e/#{ClimbOntario.Catalogue.Listing.slug(@listing)}"} class="link link-hover">{@listing.title}</a>
          </h3>
          <p :if={summary = Format.summary(@listing)} class="mt-1 text-sm text-base-content/70 line-clamp-2">
            {summary}
          </p>
          <p :if={@session && @session.cohort} class="mt-1 text-xs text-base-content/70">
            {if @classes, do: ClimbOntarioWeb.ClassSchedule.label(@listing, @session.cohort), else: @session.cohort}
          </p>
          <p :if={@place != @gym} class="mt-2 text-sm text-base-content/70">
            {Format.venue_line(@place)}
          </p>
          <div class="mt-2 text-sm text-base-content/70">
            <span :if={@place != @gym}>By </span>
            <a
              :if={website = Format.gym_website(@gym)}
              href={website}
              target="_blank"
              rel="noopener"
              class="link link-hover"
            >{Format.venue_line(@gym)}</a>
            <span :if={!Format.gym_website(@gym)}>{Format.venue_line(@gym)}</span>
            <a
              :if={map = Format.map_url(@place)}
              href={map}
              target="_blank"
              rel="noopener"
              class="mt-1 block w-fit py-1 link link-hover"
              aria-label={"Map of #{@place.name}"}
            >Map ↗</a>
          </div>
        </div>
      </div>
    </article>
    """
  end

  # The holds tucked behind card corners: baked low-poly rocks (assets/bake/rocks.mjs),
  # one per kind, drawn in currentColor so CSS gives each its colour.
  @rocks Map.new(~w(competition social class camp), fn kind ->
           path = Path.join(__DIR__, "rocks/#{kind}.svg")
           Module.put_attribute(__MODULE__, :external_resource, path)
           inner = path |> File.read!() |> String.replace(~r/\A<svg[^>]*>|<\/svg>\s*\z/, "")
           {kind, inner}
         end)

  @doc "Defines every rock once per page; cards and pages then reference them by id."
  def rock_defs(assigns) do
    assigns = assign(assigns, rocks: Enum.map(@rocks, fn {k, inner} -> {k, Phoenix.HTML.raw(inner)} end))

    ~H"""
    <svg width="0" height="0" style="position:absolute" aria-hidden="true">
      <symbol :for={{kind, inner} <- @rocks} id={"rock-#{kind}"} viewBox="0 0 100 100" shape-rendering="crispEdges">
        {inner}
      </symbol>
    </svg>
    """
  end

  attr :kind, :string, required: true
  attr :large, :boolean, default: false

  def rock(assigns) do
    ~H"""
    <svg class={["blob", "blob-#{@kind}", @large && "blob-lg"]} aria-hidden="true"><use href={"#rock-#{@kind}"} /></svg>
    """
  end

  attr :listing, :map, required: true

  def kind_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm font-medium", "kind-#{@listing.kind}"]}>
      <.icon name={kind_icon(@listing.kind)} class="size-3.5" /> {Format.badge(@listing)}
    </span>
    """
  end

  def kind_icon("competition"), do: "hero-trophy"
  def kind_icon("social"), do: "hero-user-group"
  def kind_icon("class"), do: "hero-academic-cap"
  def kind_icon("camp"), do: "hero-sun"

  attr :patch, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, default: nil
  attr :kind, :string, default: nil, doc: "colour the chip with this kind's hold colour"
  slot :inner_block, required: true

  def chip(assigns) do
    ~H"""
    <.link
      patch={@patch}
      replace
      class={["chip", @kind && "chip-#{@kind}", @active && "chip-active"]}
      aria-pressed={to_string(@active)}
    >
      <span :if={@kind} class={["hold", "hold-#{@kind}"]} aria-hidden="true"></span>
      <.icon :if={@icon && !@kind} name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  The one outbound step on an event page. Wording lives here, not in records: a record
  supplies only the destination and whether it is an event page or just the gym's homepage.
  """
  attr :listing, :map, required: true

  def organizer_cta(assigns) do
    ~H"""
    <div class="mt-6">
      <a
        href={@listing.link}
        target="_blank"
        rel="noopener"
        class="cta btn btn-primary btn-lg rounded-field w-full sm:w-auto"
      >
        {Format.link_label(@listing.link_kind)} <span class="arrow">↗</span>
      </a>
      <p class="mt-2 text-xs text-base-content/60">
        <%= if @listing.link_kind == "gym" do %>
          We didn't find a page for this event; the organizer's site is the place to ask.
        <% else %>
          Latest details and booking information from the organizer.
        <% end %>
      </p>
    </div>
    """
  end

  @doc "Shares this page (ours, not the organizer's). Native share sheet on phones, clipboard elsewhere."
  attr :url, :string, required: true
  attr :title, :string, required: true

  def share_button(assigns) do
    ~H"""
    <button
      type="button"
      data-share
      data-url={@url}
      data-title={@title}
      class="btn btn-ghost btn-sm rounded-field"
    >
      <.icon name="hero-share" class="size-4" /> <span data-label>Share</span>
    </button>
    """
  end
end
