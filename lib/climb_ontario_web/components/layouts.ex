defmodule ClimbOntarioWeb.Layouts do
  @moduledoc "Root skeleton (root.html.heex) and the app chrome around every page."
  use ClimbOntarioWeb, :html

  embed_templates "layouts/*"

  attr :flash, :map, required: true
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-dvh flex flex-col">
      <header class="px-4 sm:px-6 py-3">
        <div class="mx-auto max-w-3xl flex items-center justify-between">
          <a href="/" class="wordmark flex items-center gap-2 text-lg font-bold tracking-tight">
            <span class="hold" aria-hidden="true"></span> Climb Ontario
          </a>
          <span class="hidden sm:inline text-xs text-base-content/60">Competitions · Socials · Classes · Camps</span>
        </div>
      </header>
      <main class="flex-1 px-4 sm:px-6 pb-16">
        <div class="mx-auto max-w-3xl">
          {render_slot(@inner_block)}
        </div>
      </main>
      <footer class="px-4 sm:px-6 py-8 text-xs text-base-content/60 border-t border-base-300">
        <div class="mx-auto max-w-3xl space-y-1">
          <p>
            Listings are gathered from gym websites, social posts and the Ontario Climbing Federation. Details change; always confirm with the organizer before you go.
          </p>
          <p>
            Something wrong or missing?
            <a class="link" href="mailto:hello@climbontario.example">Tell us.</a>
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
