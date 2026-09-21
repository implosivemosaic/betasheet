defmodule ClimbOntario.Repo.Migrations.AddBundleClassification do
  use Ecto.Migration

  # Additive only (SQLite cannot add CHECKs later; the changeset owns the enum). A listing that bundles several classes records what the
  # classes are split by, and each class carries the facts that distinguish it.
  def change do
    alter table(:listings) do
      add :bundled_by, :string
      add :classes, {:array, :map}, null: false, default: []
    end
  end
end
