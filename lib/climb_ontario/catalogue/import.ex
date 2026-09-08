defmodule ClimbOntario.Catalogue.Import do
  @moduledoc """
  The write path for curated listings. Validates one listing and its confirmed dates,
  then writes both in one transaction. Never parses prose; a row that doesn't fit is rejected.
  """
  import Ecto.Query
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Occurrence}

  @doc """
  Insert or fully replace a listing. `attrs` are the listing columns; `dates` are the
  confirmed occurrence dates (replace the existing set). Returns {:ok, listing} or
  {:error, changeset}.
  """
  def put_listing(attrs, dates \\ []) do
    id = attrs[:id] || attrs["id"]

    Repo.transaction(fn ->
      existing = if id, do: Repo.get(Listing, id), else: nil

      case Listing.changeset(existing || %Listing{}, attrs) |> Repo.insert_or_update() do
        {:ok, listing} ->
          Repo.delete_all(from o in Occurrence, where: o.listing_id == ^listing.id)

          rows =
            dates
            |> Enum.map(&to_date!/1)
            |> Enum.uniq()
            |> Enum.map(&%{listing_id: listing.id, date: &1})

          if rows != [], do: Repo.insert_all(Occurrence, rows)
          listing

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc "Flip a listing to published once its judgment fields pass validation."
  def publish(id) do
    Repo.get!(Listing, id) |> Listing.changeset(%{published: true}) |> Repo.update()
  end

  defp to_date!(%Date{} = d), do: d
  defp to_date!(s) when is_binary(s), do: Date.from_iso8601!(s)
end
