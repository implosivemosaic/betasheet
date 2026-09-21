defmodule ClimbOntarioWeb.Router do
  use ClimbOntarioWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ClimbOntarioWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug ClimbOntarioWeb.Plugs.Track
  end

  pipeline :download do
    plug :put_secure_browser_headers
  end

  scope "/", ClimbOntarioWeb do
    pipe_through :download
    get "/e/:listing_id/sessions/:session_id/calendar.ics", CalendarController, :download
    get "/e/:listing_id/calendar.ics", CalendarController, :listing
  end

  scope "/", ClimbOntarioWeb do
    pipe_through :browser

    live "/", DiscoverLive, :index
    live "/location-data", LocationCreditsLive, :index
    get "/healthz", HealthController, :show
    get "/about", PageController, :about
    get "/e/:slug", ListingController, :show
  end
end
