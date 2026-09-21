defmodule ClimbOntarioWeb.Layouts do
  @moduledoc "Root skeleton (root.html.heex) and the app chrome around every page."
  use ClimbOntarioWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-dvh flex flex-col">
      <ClimbOntarioWeb.ListingComponents.rock_defs />
      <header class="pl-4 pr-11 sm:pl-6 lg:pr-6 py-3">
        <div class="mx-auto max-w-3xl flex items-center justify-between">
          <a href="/" class="wordmark flex items-center gap-2 text-lg font-extrabold tracking-tight">
            <span class="holds" aria-hidden="true">
              <span class="hold hold-competition"></span>
              <span class="hold hold-social"></span>
              <span class="hold hold-class"></span>
            </span>
            Beta Sheet
          </a>
          <nav class="flex items-center gap-4 text-sm">
            <span class="hidden sm:inline text-xs text-base-content/60">Comps · Socials · Classes · Camps</span>
            <a href="/about" class="link link-hover">About</a>
          </nav>
        </div>
      </header>
      <main class="flex-1 pl-4 pr-11 sm:pl-6 lg:pr-6 pb-16">
        <div class="mx-auto max-w-3xl">
          {render_slot(@inner_block)}
        </div>
      </main>
      <footer class="pl-4 pr-11 sm:pl-6 lg:pr-6 py-8 text-xs text-base-content/60 border-t border-base-300">
        <div class="mx-auto max-w-3xl space-y-1">
          <p>
            Listings are gathered from gym websites, social posts and the Ontario Climbing Federation. Details change; always confirm with the organizer before you go.
          </p>
          <p>
            <a class="link" href="/location-data">Location data: OpenCage · © OpenStreetMap contributors</a>
          </p>
          <p>
            Something wrong or missing?
            <a class="link" href={"mailto:#{ClimbOntario.contact_email()}"}>Tell us.</a>
            · <a class="link" href="/about">About this site</a>
          </p>
        </div>
      </footer>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end
end
