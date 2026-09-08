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
      class="card-lift block rounded-box bg-base-100 border border-base-300 p-4 shadow-sm"
    >
      <div class="flex items-center justify-between gap-2 text-xs">
        <.kind_badge listing={@listing} />
        <span :if={soon = Format.soon(@listing, @today)} class="badge badge-sm badge-secondary">{soon}</span>
      </div>
      <h3 class="mt-1.5 text-lg font-semibold leading-snug text-balance">{@listing.title}</h3>
      <p class="mt-0.5 text-sm text-base-content/70">
        {Format.venue_line(@listing.venue)}<span :if={d = Format.distance(@listing.distance_km)}> · {d}</span>
      </p>
      <p class="mt-2 text-sm flex items-start gap-1.5">
        <.icon name="hero-calendar-days" class="size-4 mt-0.5 shrink-0 text-primary" />
        <span>
          <span class="font-medium">{Format.when_line(@listing, @today)}</span>
          <span
            :if={@listing.schedule_note && @listing.schedule_kind in ~w(recurring course)}
            class="text-base-content/70"
          > · {@listing.schedule_note}</span>
        </span>
      </p>
      <p :if={@listing.summary != ""} class="mt-2 text-sm text-base-content/80 line-clamp-2">
        {@listing.summary}
      </p>
      <div class="mt-3 flex flex-wrap items-center gap-1.5 text-xs">
        <span :if={@listing.ages} class="tag">{@listing.ages}</span>
        <span :for={a <- @listing.audience -- ["youth", "adult"]} class="tag">{Format.audience_label(
          a
        )}</span>
        <span :if={p = Format.price(@listing)} class="tag tag-price">{p}</span>
        <span :if={@listing.confidence == "tentative"} class="tag tag-muted">Tentative</span>
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
  slot :inner_block, required: true

  def chip(assigns) do
    ~H"""
    <.link
      patch={@patch}
      replace
      class={["chip", @active && "chip-active"]}
      aria-pressed={to_string(@active)}
    >
      <.icon :if={@icon} name={@icon} class="size-4" />
      {render_slot(@inner_block)}
    </.link>
    """
  end
end
