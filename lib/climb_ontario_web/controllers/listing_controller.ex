defmodule ClimbOntarioWeb.ListingController do
  @moduledoc "Permanent event pages. Plain HTML so link previews work anywhere."
  use ClimbOntarioWeb, :controller
  alias ClimbOntario.{Catalogue, Clock}
  alias ClimbOntario.Catalogue.Listing
  alias ClimbOntarioWeb.Format

  def show(conn, %{"slug" => slug}) do
    with {id, _} <- Integer.parse(slug),
         %Listing{} = listing <- Catalogue.get_listing(id) do
      if Listing.slug(listing) == slug do
        today = Clock.today()

        render(conn, :show,
          listing: listing,
          today: today,
          page_title: listing.title,
          meta: meta(listing, today, url(conn, ~p"/e/#{Listing.slug(listing)}"))
        )
      else
        conn |> put_status(:moved_permanently) |> redirect(to: ~p"/e/#{Listing.slug(listing)}")
      end
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(html: ClimbOntarioWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  defp meta(listing, today, url) do
    %{
      title: listing.title,
      description:
        [
          Format.when_line(listing, today),
          "#{listing.venue.name}, #{listing.venue.city}",
          listing.summary
        ]
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.join(" · ")
        |> String.slice(0, 200),
      url: url
    }
  end
end
