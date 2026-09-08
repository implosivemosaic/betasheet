defmodule ClimbOntarioWeb.ListingComponents do
  @moduledoc "Cards, badges and filter chips shared by the discovery page and event pages."
  use ClimbOntarioWeb, :html
  alias ClimbOntarioWeb.Format

  attr :listing, :map, required: true
  attr :today, Date, required: true

  def listing_card(assigns) do
    ~H"""
    <a
      href={~p"/e/#{ClimbOntario.Catalogue.Listing.slug(@listing)}"}
      class="card-lift group relative block overflow-hidden rounded-box bg-base-100 border border-base-300 p-4 shadow-sm"
    >
      <span class={["blob", "blob-#{@listing.kind}"]} aria-hidden="true"></span>
      <div class="relative flex gap-3">
        <div :if={@listing.start_date && @listing.schedule_kind != "recurring"} class="datebox">
          <span class="datebox-day">{Format.day(@listing.start_date)}</span>
          <span class="datebox-month">{Format.month(@listing.start_date)}</span>
        </div>
        <div
          :if={!(@listing.start_date && @listing.schedule_kind != "recurring")}
          class="datebox datebox-soft"
        >
          <.icon name="hero-arrow-path" class="size-5" />
        </div>
        <div class="min-w-0 flex-1">
          <div class="flex items-center justify-between gap-2 text-xs">
            <.kind_badge listing={@listing} />
            <span :if={soon = Format.soon(@listing, @today)} class="badge badge-sm badge-primary">{soon}</span>
          </div>
          <h3 class="mt-1.5 text-lg font-bold leading-snug tracking-tight text-balance">
            {@listing.title}
          </h3>
          <p class="mt-0.5 text-sm text-base-content/70">
            {Format.venue_line(@listing.venue)}<span :if={d = Format.distance(@listing.distance_km)}> · {d}</span>
          </p>
          <p class="mt-1.5 text-sm">
            <span class="font-medium">{Format.when_line(@listing, @today)}</span>
            <span
              :if={@listing.schedule_note && @listing.schedule_kind in ~w(recurring course)}
              class="text-base-content/70"
            > · {@listing.schedule_note}</span>
          </p>
          <p :if={@listing.summary != ""} class="mt-2 text-sm text-base-content/80 line-clamp-2">
            {@listing.summary}
          </p>
          <div class="mt-3 flex flex-wrap items-center gap-1.5 text-xs">
            <span :if={@listing.ages} class="tag">{@listing.ages}</span>
            <span :for={a <- @listing.audience -- ["youth", "adult"]} class="tag">{Format.audience_label(
              a
            )}</span>
            <span :if={@listing.confidence == "tentative"} class="tag tag-muted">Tentative</span>
          </div>
        </div>
      </div>
    </a>
    """
  end

  attr :listing, :map, required: true

  def kind_badge(assigns) do
    ~H"""
    <span class={["badge badge-sm font-medium", "kind-#{@listing.kind}"]}>
      <.icon name={kind_icon(@listing.kind)} class="size-3.5" /> {@listing.label}
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
