defmodule ClimbOntario.Repo.Migrations.AddSignupLink do
  use Ecto.Migration

  # Additive only. When the main link is the organizer's announcement, this is where to sign up.
  def change do
    alter table(:listings) do
      add :signup_link, :string
    end
  end
end
