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
    window = {max_date(q.from || q.today, q.today), q.to}

    listings =
      Repo.all(from l in Listing, where: l.published, preload: [:venue, occurrences: :venue])
      |> Enum.reject(&(&1.schedule_kind == "unscheduled" or over?(&1, q.today)))
      |> Enum.filter(&ClimbOntario.Catalogue.Keyword.matches?(&1, q.keyword))
      |> Enum.map(&match_schedule(&1, q, window))
      |> Enum.filter(&within?(&1, q))
      |> Enum.filter(&kind?(&1, q.kinds))
      |> Enum.filter(&audience?(&1, q.audience))

    dated =
      listings
      |> Enum.filter(&(&1.discovery_date != nil))
      |> Enum.sort_by(&sort_key(&1, q.today), &date_tuple_lte/2)

    ongoing =
      listings
      |> Enum.filter(
        &(&1.schedule_kind == "recurring" and &1.discovery_date == nil and
            not Query.dated_filter?(q) and
            not Enum.any?(&1.occurrences, fn o -> Date.compare(o.date, q.today) != :lt end))
      )
      |> Enum.sort_by(&{&1.schedule_kind != "recurring", &1.distance_km || 0.0, &1.title})

    %{dated: dated, ongoing: ongoing, total: length(dated) + length(ongoing)}
  end

  @doc "A published listing by research id, with venue. Drafts are invisible."
  def get_listing(id) when is_integer(id) do
    Repo.one(
      from l in Listing,
        where: l.id == ^id and l.published,
        preload: [:venue, occurrences: :venue]
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

  # Date and distance predicates apply to the same session before selecting its date.
  defp match_schedule(l, q, {from, to}) do
    sessions =
      Enum.filter(l.occurrences, fn o ->
        overlaps?(o.date, o.date, from, to) and weekday?(o.date, q.days) and
          place_within?(Listing.location(l, o), q)
      end)

    selected = Enum.min_by(sessions, &ClimbOntario.Catalogue.Occurrence.sort_key/1, fn -> nil end)
    next = if selected, do: selected.date

    fallback =
      if l.occurrences == [] and place_within?(Listing.location(l), q) do
        cond do
          l.schedule_kind in ~w(one_off multi_day) ->
            interval_date(l.start_date, l.end_date || l.start_date, from, to, q.days)

          l.schedule_kind == "course" and not Query.dated_filter?(q) ->
            max_date(l.start_date, from)

          true ->
            nil
        end
      end

    # Preserve Anytime's term-bound fallback for courses without upcoming sessions.
    fallback =
      fallback ||
        if(
          l.schedule_kind == "course" and not Query.dated_filter?(q) and q.near == nil and
            not Enum.any?(l.occurrences, &(Date.compare(&1.date, from) != :lt)),
          do: max_date(l.start_date, from)
        )

    places =
      if sessions != [],
        do: Enum.map(sessions, &Listing.location(l, &1)),
        else: [Listing.location(l)]

    distance =
      places
      |> Enum.map(&distance(&1, q.near))
      |> Enum.reject(&is_nil/1)
      |> Enum.min(fn -> nil end)

    %{
      l
      | discovery_date: next || fallback,
        distance_km: distance,
        discovery_occurrence_id: selected && selected.id
    }
  end

  defp weekday?(_, []), do: true
  defp weekday?(d, days), do: Date.day_of_week(d) in days

  defp interval_date(s, e, from, to, days) do
    first = max_date(s, from)
    # At most seven arithmetic candidates, irrespective of interval length.
    offset =
      if days == [],
        do: 0,
        else: Enum.min(Enum.map(days, &Integer.mod(&1 - Date.day_of_week(first), 7)))

    candidate = Date.add(first, offset)

    if Date.compare(candidate, e) != :gt and (is_nil(to) or Date.compare(candidate, to) != :gt),
      do: candidate
  end

  defp distance(_, nil), do: nil

  defp distance(%{lat: lat, lng: lng}, near) when is_number(lat) and is_number(lng),
    do: Geo.distance_km(near.lat, near.lng, lat, lng)

  defp distance(_, _), do: nil
  defp place_within?(_, %{near: nil}), do: true

  defp place_within?(place, q) do
    d = distance(place, q.near)
    not is_nil(d) and d <= q.radius_km
  end

  defp overlaps?(s, e, from, to) do
    Date.compare(e, from) != :lt and (is_nil(to) or Date.compare(s, to) != :gt)
  end

  # Sort by the first relevant date: next confirmed occurrence in the window, else start date;
  # things already under way sort as today, after anything that actually starts today.
  @doc "Next confirmed date in the discovery window, otherwise the known event/term bound."
  def relevant_date(l, {from, to}) do
    next_occ =
      l.occurrences
      |> Enum.map(& &1.date)
      |> Enum.filter(&overlaps?(&1, &1, from, to))
      |> Enum.min(Date, fn -> nil end)

    next_occ ||
      if(l.schedule_kind in ~w(one_off multi_day course) and l.start_date,
        do: max_date(l.start_date, from)
      )
  end

  defp sort_key(l, today) do
    in_progress = l.schedule_kind == "course" and Date.compare(l.start_date, today) == :lt
    {l.discovery_date, {in_progress, l.distance_km || 0.0, l.title}}
  end

  defp date_tuple_lte({d1, r1}, {d2, r2}) do
    case Date.compare(d1, d2) do
      :lt -> true
      :gt -> false
      :eq -> r1 <= r2
    end
  end

  defp within?(_l, %{near: nil}), do: true
  defp within?(%{distance_km: nil}, _q), do: false
  defp within?(%{distance_km: d}, %{radius_km: r}), do: d <= r

  defp kind?(_l, []), do: true
  defp kind?(l, kinds), do: Listing.discovery_kind(l) in kinds

  defp audience?(_l, []), do: true
  defp audience?(l, tags), do: Enum.any?(tags, &(&1 in l.audience))

  defp max_date(a, b), do: if(Date.compare(a, b) == :lt, do: b, else: a)
end
