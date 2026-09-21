defmodule ClimbOntarioWeb.ErrorHTML do
  @moduledoc "Error pages wear the site chrome (and the climber) instead of a bare status line."
  use ClimbOntarioWeb, :html
  alias ClimbOntarioWeb.Layouts

  embed_templates "error_html/*"

  def render("404.html", assigns), do: page(assigns, &not_found/1, "Page not found")
  def render("500.html", assigns), do: page(assigns, &server_error/1, "Something went wrong")
  def render(template, _assigns), do: Phoenix.Controller.status_message_from_template(template)

  # Errors render without a root layout, so wrap the page ourselves.
  defp page(assigns, body, title) do
    assigns = Map.merge(%{flash: %{}}, Map.new(assigns))
    Layouts.root(%{inner_content: body.(assigns), flash: %{}, page_title: title, meta: nil})
  end
end
