defmodule ClimbOntario.Repo.Migrations.AddCompleteCohorts do
  use Ecto.Migration

  def change do
    alter table(:listings) do
      add :complete_cohorts, {:array, :string}, null: false, default: []
    end
  end
end
