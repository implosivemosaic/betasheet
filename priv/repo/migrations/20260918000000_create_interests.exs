defmodule ClimbOntario.Repo.Migrations.CreateInterests do
  use Ecto.Migration

  def change do
    create table(:interests) do
      add :email, :string, null: false
      add :location, :string, null: false, default: ""
      add :radius_km, :integer, null: false
      add :kinds, {:array, :string}, null: false, default: []
      add :audience, {:array, :string}, null: false, default: []
      add :consented_at, :utc_datetime, null: false
    end

    create unique_index(:interests, [:email, :location, :radius_km, :kinds, :audience],
             name: :interests_identity
           )
  end
end
