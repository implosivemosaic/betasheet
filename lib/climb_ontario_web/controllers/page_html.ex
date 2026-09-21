defmodule ClimbOntarioWeb.PageHTML do
  use ClimbOntarioWeb, :html
  import ClimbOntarioWeb.ListingComponents, only: [rock: 1]

  embed_templates "page_html/*"
end
