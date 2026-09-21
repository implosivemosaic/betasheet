# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :climb_ontario,
  ecto_repos: [ClimbOntario.Repo],
  generators: [timestamp_type: :utc_datetime]

# Interest capture is private-preview only; production remains disabled.
config :climb_ontario, :preview_interest, config_env() == :test
# Public contact address, shown on the About page and in the footer. Set CONTACT_EMAIL in production.
config :climb_ontario, :contact_email, "hello@climbontario.example"
config :phoenix, :filter_parameters, ["password", "email", "interest"]

# Configure the endpoint
config :climb_ontario, ClimbOntarioWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ClimbOntarioWeb.ErrorHTML, json: ClimbOntarioWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ClimbOntario.PubSub,
  live_view: [signing_salt: "nmMfkcdg"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  climb_ontario: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  climb_ontario: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :climb_ontario,
       :research_db,
       System.get_env("RESEARCH_DB") ||
         "/data/workspace/dot-files/knowledge/ontario-gyms/ontario-gyms.sqlite"
