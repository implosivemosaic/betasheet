defmodule ClimbOntario.Catalogue do
  @moduledoc """
  Public catalogue facade: search published listings and fetch one for its page.
  A few hundred rows, so search loads them and filters in memory.
  """
  import Ecto.Query
  alias ClimbOntario.Repo
  alias ClimbOntario.Catalogue.{Listing, Query}
  alias ClimbOntario.Geo

  @doc "Returns %{dated: [listing], ongoing: [listing], total: n}."
  def search(%Query{} = q) do
    window = window(q.when, q.today)

    listings =
      Repo.all(from l in Listing, where: l.published, preload: [:venue, :occurrences])
      |> Enum.reject(&over?(&1, q.today))
      |> Enum.map(&with_distance(&1, q.near))
      |> Enum.filter(&within?(&1, q))
      |> Enum.filter(&kind?(&1, q.kinds))
      |> Enum.filter(&audience?(&1, q.audience))

    dated =
      listings
      |> Enum.filter(&dated_match?(&1, window, q.today))
      |> Enum.sort_by(&sort_key(&1, window, q.today), &date_tuple_lte/2)

    ongoing =
      listings
      |> Enum.filter(&ongoing_match?(&1, window, q))
      |> Enum.sort_by(&{&1.schedule_kind != "recurring", &1.distance_km || 0.0, &1.title})

    dated = if q.kinds == [] and q.near == nil, do: interleave_kinds(dated), else: dated
    %{dated: dated, ongoing: ongoing, total: length(dated) + length(ongoing)}
  end

  @doc "A published listing by research id, with venue. Drafts are invisible."
  def get_listing(id) when is_integer(id) do
    Repo.one(
      from l in Listing, where: l.id == ^id and l.published, preload: [:venue, :occurrences]
    )
  end

  def get_listing(_), do: nil

  @doc "Date window as {from, to}; to = nil is open-ended. Local dates."
  def window("weekend", today) do
    dow = Date.day_of_week(today)
    saturday = if dow == 7, do: today, else: Date.add(today, 6 - dow)
    {max_date(saturday, today), Date.add(saturday, if(dow == 7, do: 0, else: 1))}
  end

  def window("week", today), do: {today, Date.add(today, 6)}
  def window("month", today), do: {today, Date.end_of_month(today)}
  def window(_, today), do: {today, nil}

  # Something whose last known date has passed stays on its page but leaves search.
  defp over?(%{schedule_kind: k} = l, today) when k in ~w(one_off multi_day course) do
    Date.compare(l.end_date || l.start_date, today) == :lt
  end

  defp over?(%{end_date: %Date{} = e}, today), do: Date.compare(e, today) == :lt
  defp over?(_, _), do: false

  # A date filter matches only a date we can stand behind: the event's own dates, or a
  # confirmed occurrence. Courses with no confirmed class dates match Anytime only.
  defp dated_match?(%{schedule_kind: k} = l, {from, to}, _today)
       when k in ~w(one_off multi_day) do
    overlaps?(l.start_date, l.end_date || l.start_date, from, to)
  end

  defp dated_match?(%{schedule_kind: "course"} = l, {from, nil}, _today),
    do: Date.compare(l.end_date, from) != :lt

  defp dated_match?(%{schedule_kind: "course"} = l, window, _), do: occurrence_in?(l, window)
  defp dated_match?(%{schedule_kind: "recurring"}, {_, nil}, _), do: false
  defp dated_match?(%{schedule_kind: "recurring"} = l, window, _), do: occurrence_in?(l, window)
  defp dated_match?(_, _, _), do: false

  # Ongoing = recurring things under Anytime (they have no matched date), plus unscheduled on request.
  defp ongoing_match?(%{schedule_kind: "recurring"}, {_, nil}, _q), do: true
  defp ongoing_match?(%{schedule_kind: "unscheduled"}, {_, nil}, q), do: q.unscheduled
  defp ongoing_match?(_, _, _), do: false

  defp occurrence_in?(l, {from, to}),
    do: Enum.any?(l.occurrences, &overlaps?(&1.date, &1.date, from, to))

  defp overlaps?(s, e, from, to) do
    Date.compare(e, from) != :lt and (is_nil(to) or Date.compare(s, to) != :gt)
  end

  # Sort by the first relevant date: next confirmed occurrence in the window, else start date;
  # things already under way sort as today, after anything that actually starts today.
  defp sort_key(l, {from, to}, today) do
    next_occ =
      l.occurrences
      |> Enum.map(& &1.date)
      |> Enum.filter(&overlaps?(&1, &1, from, to))
      |> Enum.min(Date, fn -> nil end)

    in_progress = l.schedule_kind == "course" and Date.compare(l.start_date, today) == :lt
    effective = next_occ || if(in_progress, do: today, else: l.start_date)
    {effective, {in_progress, l.distance_km || 0.0, l.title}}
  end

  defp date_tuple_lte({d1, r1}, {d2, r2}) do
    case Date.compare(d1, d2) do
      :lt -> true
      :gt -> false
      :eq -> r1 <= r2
    end
  end

  # Province-wide with no kind chosen, youth courses would bury everything else. Rotate through
  # kinds so the first screen shows the soonest competition, social, class and camp in turn.
  defp interleave_kinds(dated) do
    groups = Enum.group_by(dated, & &1.kind)
    dated |> Enum.map(& &1.kind) |> Enum.uniq() |> Enum.map(&groups[&1]) |> rotate([])
  end

  defp rotate([], acc), do: Enum.reverse(acc)

  defp rotate(lists, acc) do
    {heads, tails} = lists |> Enum.map(fn [h | t] -> {h, t} end) |> Enum.unzip()
    rotate(Enum.reject(tails, &(&1 == [])), Enum.reverse(heads) ++ acc)
  end

  # Offsite events use their own coordinates; without any, they have no distance and stay out
  # of radius searches rather than borrowing the host gym's location.
  defp with_distance(l, nil), do: l

  defp with_distance(l, %{lat: lat, lng: lng}) do
    case location(l) do
      {vlat, vlng} -> %{l | distance_km: Geo.distance_km(lat, lng, vlat, vlng)}
      nil -> l
    end
  end

  defp location(%{offsite_name: name, offsite_lat: lat, offsite_lng: lng}) when is_binary(name),
    do: if(lat && lng, do: {lat, lng}, else: nil)

  defp location(%{venue: %{lat: lat, lng: lng}}), do: if(lat && lng, do: {lat, lng}, else: nil)

  defp within?(_l, %{near: nil}), do: true
  defp within?(%{distance_km: nil}, _q), do: false
  defp within?(%{distance_km: d}, %{radius_km: r}), do: d <= r

  defp kind?(_l, []), do: true
  defp kind?(l, kinds), do: l.kind in kinds

  defp audience?(_l, []), do: true
  defp audience?(l, tags), do: Enum.any?(tags, &(&1 in l.audience))

  defp max_date(a, b), do: if(Date.compare(a, b) == :lt, do: b, else: a)
end
