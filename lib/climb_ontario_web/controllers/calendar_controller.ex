defmodule ClimbOntarioWeb.CalendarController do
  use ClimbOntarioWeb, :controller
  alias ClimbOntario.Catalogue
  alias ClimbOntario.Catalogue.Listing
  alias ClimbOntarioWeb.SessionCalendar

  def download(conn, %{"listing_id" => listing_id, "session_id" => session_id}) do
    conn = put_resp_header(conn, "cache-control", "no-store")

    with {:ok, listing_id} <- id(listing_id),
         {:ok, session_id} <- id(session_id),
         %Listing{} = listing <- Catalogue.get_listing(listing_id),
         session when not is_nil(session) <-
           Enum.find(listing.occurrences, &(&1.id == session_id)),
         {:ok, calendar} <-
           SessionCalendar.render(
             listing,
             session,
             url(ClimbOntarioWeb.Endpoint, ~p"/e/#{Listing.slug(listing)}"),
             DateTime.utc_now()
           ) do
      conn
      |> put_resp_content_type("text/calendar", "utf-8")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="climb-#{listing_id}-#{session_id}.ics")
      )
      |> send_resp(200, calendar)
    else
      _ -> conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found")
    end
  end

  # The whole run (or one named group) as a single file; served inline so phones
  # open it straight in Calendar, and subscribable at the same address via webcal.
  def listing(conn, %{"listing_id" => listing_id} = params) do
    conn = put_resp_header(conn, "cache-control", "no-store")
    cohort = params["cohort"]

    with {:ok, listing_id} <- id(listing_id),
         %Listing{} = listing <- Catalogue.get_listing(listing_id),
         true <- is_nil(cohort) or cohort in listing.cohorts,
         {:ok, calendar} <-
           ClimbOntarioWeb.ListingCalendar.render(
             listing,
             cohort,
             url(ClimbOntarioWeb.Endpoint, ~p"/e/#{Listing.slug(listing)}"),
             DateTime.utc_now()
           ) do
      conn
      |> put_resp_content_type("text/calendar", "utf-8")
      |> put_resp_header("content-disposition", ~s(inline; filename="climb-#{listing_id}.ics"))
      |> send_resp(200, calendar)
    else
      _ -> conn |> put_resp_content_type("text/plain") |> send_resp(404, "Not found")
    end
  end

  defp id(value) when is_binary(value) do
    if Regex.match?(~r/\A[1-9][0-9]{0,17}\z/, value),
      do: {:ok, String.to_integer(value)},
      else: :error
  end

  defp id(_), do: :error
end
