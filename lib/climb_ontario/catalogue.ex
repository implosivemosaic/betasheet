defmodule ClimbOntario.Catalogue do
  @moduledoc """
  Public catalogue facade: search listings and fetch one for its page.
  The whole listed catalogue is a few hundred rows, so search loads it and
  filters in memory; that keeps date-window and distance logic in plain Elixir.
  """
  import Ecto.Query
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Query}
  alias ClimbOntario.Geo

  @doc "Returns %{dated: [listing], ongoing: [listing], total: n}."
  def search(%Query{} = q) do
    window = window(q.when, q.today)

    listings =
      Repo.all(from l in Listing, where: l.listed, preload: :venue)
      |> Enum.map(&with_distance(&1, q.near))
      |> Enum.filter(&within?(&1, q))
      |> Enum.filter(&kind?(&1, q.kinds))
      |> Enum.filter(&audience?(&1, q.audience))

    dated =
      listings
      |> Enum.filter(
        &(&1.schedule_kind in ~w(one_off multi_day course) and in_window?(&1, window))
      )
      |> Enum.sort_by(&sort_key(&1, q.today), fn {d1, rest1}, {d2, rest2} ->
        case Date.compare(d1, d2) do
          :lt -> true
          :gt -> false
          :eq -> rest1 <= rest2
        end
      end)

    ongoing =
      listings
      |> Enum.filter(
        &(&1.schedule_kind == "recurring" or (q.unscheduled and &1.schedule_kind == "unscheduled"))
      )
      |> Enum.sort_by(&{&1.schedule_kind != "recurring", &1.distance_km || 0.0, &1.title})

    %{dated: dated, ongoing: ongoing, total: length(dated) + length(ongoing)}
  end

  @doc "Fetch a listing by the research event id that leads its slug (stable across rebuilds), with venue."
  def get_listing(source_event_id) when is_integer(source_event_id) do
    Repo.one(from l in Listing, where: l.source_event_id == ^source_event_id, preload: :venue)
  end

  def get_listing(_), do: nil

  @doc "Date window as {from, to} with to = nil for open-ended, in the visitor's local date."
  def window("weekend", today) do
    dow = Date.day_of_week(today)
    saturday = if dow == 7, do: today, else: Date.add(today, 6 - dow)
    {max_date(saturday, today), Date.add(saturday, if(dow == 7, do: 0, else: 1))}
  end

  def window("week", today), do: {today, Date.add(today, 7)}
  def window("month", today), do: {today, Date.add(today, 31)}
  def window(_, today), do: {today, nil}

  # Things already under way sort as "today", after anything that actually starts today.
  defp sort_key(l, today) do
    in_progress = Date.compare(l.start_date, today) == :lt
    effective = if in_progress, do: today, else: l.start_date
    {effective, {in_progress, l.distance_km || 0.0, l.title}}
  end

  defp in_window?(l, {from, to}) do
    last = l.end_date || l.start_date
    starts_before_end = is_nil(to) or Date.compare(l.start_date, to) != :gt
    ends_after_start = Date.compare(last, from) != :lt
    starts_before_end and ends_after_start
  end

  defp with_distance(l, nil), do: l

  defp with_distance(%{venue: v} = l, %{lat: lat, lng: lng}) do
    if v.lat && v.lng, do: %{l | distance_km: Geo.distance_km(lat, lng, v.lat, v.lng)}, else: l
  end

  defp within?(_l, %{near: nil}), do: true
  defp within?(%{distance_km: nil}, _q), do: false
  defp within?(%{distance_km: d}, %{radius_km: r}), do: d <= r

  defp kind?(_l, []), do: true
  defp kind?(l, kinds), do: l.kind in kinds

  defp audience?(_l, []), do: true
  defp audience?(l, tags), do: Enum.any?(tags, &(&1 in l.audience))

  defp max_date(a, b), do: if(Date.compare(a, b) == :lt, do: b, else: a)
end
