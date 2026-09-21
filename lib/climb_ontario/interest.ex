defmodule ClimbOntario.Interest do
  @moduledoc "Preview-only interest capture. No delivery, subscriptions, or address read API."
  use Ecto.Schema
  import Ecto.Changeset
  alias ClimbOntario.{Repo, Geo}
  alias ClimbOntario.Catalogue.Listing

  schema "interests" do
    field :email, :string, redact: true
    field :location, :string, default: ""
    field :radius_km, :integer, default: 40
    field :kinds, {:array, :string}, default: []
    field :audience, {:array, :string}, default: []
    field :consented_at, :utc_datetime
    field :consent, :boolean, virtual: true, default: false
  end

  def enabled?, do: Application.get_env(:climb_ontario, :preview_interest, false)

  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:email, :location, :radius_km, :kinds, :audience, :consent])
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> update_change(:location, &String.trim/1)
    |> update_change(:kinds, &normalize_tags/1)
    |> update_change(:audience, &normalize_tags/1)
    |> validate_required([:email, :radius_km])
    |> validate_length(:email, max: 254)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@.]+(?:\.[^\s@.]+)+$/u)
    |> validate_number(:radius_km, greater_than: 0, less_than_or_equal_to: 500)
    |> validate_subset(:kinds, Listing.discovery_kinds())
    |> validate_subset(:audience, Listing.audiences())
    |> validate_acceptance(:consent)
    |> validate_change(:location, fn :location, text ->
      if text == "" or match?({:ok, _}, Geo.resolve(text)),
        do: [],
        else: [location: "use a recognized Ontario city or postal code, or leave blank"]
    end)
  end

  defp normalize_tags(tags), do: tags |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.sort()

  def save(attrs) do
    if enabled?() do
      attrs
      |> changeset()
      |> put_change(:consented_at, DateTime.utc_now() |> DateTime.truncate(:second))
      |> Repo.insert(on_conflict: :nothing, log: false)
      |> case do
        {:ok, _} -> :ok
        {:error, cs} -> {:error, cs}
      end
    else
      {:error, :disabled}
    end
  end
end
