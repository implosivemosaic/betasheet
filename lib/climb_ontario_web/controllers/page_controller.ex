defmodule ClimbOntarioWeb.PageController do
  @moduledoc "Plain pages: About."
  use ClimbOntarioWeb, :controller

  def about(conn, _params) do
    render(conn, :about,
      page_title: "About",
      contact: ClimbOntario.contact_email(),
      meta: %{
        title: "About Beta Sheet",
        description: "A free, hand-checked guide to climbing competitions, socials, classes and camps across Ontario.",
        url: url(conn, ~p"/about")
      }
    )
  end
end
