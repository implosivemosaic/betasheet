defmodule ClimbOntario.Repo do
  use Ecto.Repo,
    otp_app: :climb_ontario,
    adapter: Ecto.Adapters.SQLite3
end
