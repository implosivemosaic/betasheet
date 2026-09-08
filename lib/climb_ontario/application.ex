defmodule ClimbOntario.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ClimbOntarioWeb.Telemetry,
      ClimbOntario.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:climb_ontario, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:climb_ontario, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ClimbOntario.PubSub},
      # Start a worker by calling: ClimbOntario.Worker.start_link(arg)
      # {ClimbOntario.Worker, arg},
      # Start to serve requests, typically the last entry
      ClimbOntarioWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ClimbOntario.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ClimbOntarioWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
