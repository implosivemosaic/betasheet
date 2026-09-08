defmodule ClimbOntarioWeb.Router do
  use ClimbOntarioWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ClimbOntarioWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", ClimbOntarioWeb do
    pipe_through :browser

    live "/", DiscoverLive, :index
    get "/e/:slug", ListingController, :show
  end
end
