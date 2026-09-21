defmodule ClimbOntarioWeb.Format do
  @moduledoc "Pure formatters for dates, times, distance and labels shown to visitors."

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  def date(nil), do: nil

  def date(%Date{} = d),
    do: "#{Enum.at(@days, Date.day_of_week(d) - 1)} #{Enum.at(@months, d.month - 1)} #{d.day}"

  def date_with_year(%Date{} = d), do: date(d) <> ", #{d.year}"

  def day(%Date{day: d}), do: Integer.to_string(d)
  def month(%Date{} = d), do: Calendar.strftime(d, "%b")

  def time(nil), do: nil

  def time(%Time{hour: h, minute: m}) do
    {h12, ampm} =
      cond do
        h == 0 -> {12, "am"}
        h < 12 -> {h, "am"}
        h == 12 -> {12, "pm"}
        true -> {h - 12, "pm"}
      end

    if m == 0, do: "#{h12} #{ampm}", else: "#{h12}:#{String.pad_leading("#{m}", 2, "0")} #{ampm}"
  end

  @doc "One line that answers 'when?' for a card."
  def when_line(listing, today \\ nil)

  def when_line(%{schedule_kind: "recurring", discovery_date: %Date{} = d}, _),
    do: date(d)

  def when_line(%{schedule_kind: "recurring", occurrences: occ}, today)
      when is_list(occ) and occ != [] do
    next =
      occ
      |> Enum.map(& &1.date)
      |> Enum.filter(&(is_nil(today) or Date.compare(&1, today) != :lt))
      |> Enum.min(Date, fn -> nil end)

    if next, do: "Next #{date(next)}", else: "No further dates confirmed"
  end

  def when_line(%{schedule_kind: "recurring"}, _), do: "Dates not confirmed"
  def when_line(%{schedule_kind: "unscheduled"}, _), do: "Schedule not posted yet"

  def when_line(%{schedule_kind: "one_off", occurrences: [_ | _], start_date: d}, _),
    do: date(d)

  def when_line(%{schedule_kind: "one_off", start_date: d} = l, _),
    do: join([date(d), time_line(l)])

  def when_line(%{schedule_kind: "multi_day", start_date: s, end_date: e}, _),
    do: "#{date(s)} – #{date(e)}"

  def when_line(%{schedule_kind: "course", start_date: s, end_date: e}, today) do
    if today && Date.compare(s, today) == :lt,
      do: "Until #{date(e)}",
      else: "#{date(s)} – #{short_date(e)}"
  end

  @doc "Month and day only, for the end of a range."
  def short_date(%Date{} = d), do: "#{Enum.at(@months, d.month - 1)} #{d.day}"

  @doc "8–10 am, 7 pm – 9:30 pm, 9 am, or nil."
  def time_range(nil, _), do: nil
  def time_range(s, nil), do: time(s)

  def time_range(s, e) do
    [a, b] = [time(s), time(e)]
    [_, suffix_a] = String.split(a, " ")
    [_, suffix_b] = String.split(b, " ")

    if suffix_a == suffix_b,
      do: "#{String.replace_suffix(a, " " <> suffix_a, "")}–#{b}",
      else: "#{a} – #{b}"
  end

  @doc "Next confirmed date of a recurring listing, or nil."
  def next_date(%{occurrences: occ}, today) when is_list(occ) do
    occ
    |> Enum.map(& &1.date)
    |> Enum.filter(&(Date.compare(&1, today) != :lt))
    |> Enum.min(Date, fn -> nil end)
  end

  def next_date(_, _), do: nil

  @doc "Venue name plus city, unless the name already says the city."
  def venue_line(%{name: name, city: nil}), do: "#{name} · City not announced"

  def venue_line(%{name: name, city: city}) do
    if String.contains?(String.downcase(name), String.downcase(city)),
      do: name,
      else: "#{name} · #{city}"
  end

  def link_label("gym"), do: "Visit organizer's website"
  def link_label(_), do: "View original event"

  def distance(nil), do: nil
  def distance(km) when km < 1, do: "<1 km"
  def distance(km) when km < 10, do: "#{Float.round(km, 1)} km"
  def distance(km), do: "#{round(km)} km"

  def kind_label("ocf"), do: "OCF"
  def kind_label("competition"), do: "Other comps"
  def kind_label("social"), do: "Socials"
  def kind_label("class"), do: "Classes"
  def kind_label("camp"), do: "Camps"

  def badge(%{kind: "competition", ocf: true}), do: "OCF competition"
  def badge(%{kind: "competition"}), do: "Competition"
  def badge(%{kind: "social"}), do: "Social"
  def badge(%{kind: "class"}), do: "Class / clinic"
  def badge(%{kind: "camp"}), do: "Camp"

  def audience_label("youth"), do: "Kids & youth"
  def audience_label("adult"), do: "Adults"
  def audience_label("family"), do: "Families"
  def audience_label("adaptive"), do: "Adaptive"
  def audience_label("women"), do: "Women"
  def audience_label("queer"), do: "LGBTQ+"

  def when_label("all"), do: "Anytime"
  def when_label("weekend"), do: "Weekend"
  def when_label("week"), do: "7 days"
  def when_label("month"), do: "Month"

  def location_line(l), do: l |> ClimbOntario.Catalogue.Listing.display_location() |> venue_line()

  def time_line(l) do
    join([
      time_range(l.start_time, l.end_time) || "Time not announced",
      l.timezone || "Timezone not confirmed"
    ])
  end

  def pattern(%{recurrence: "weekly", weekday: day} = l),
    do: join(["Every #{Enum.at(@days, day - 1)}", time_line(l)])

  def pattern(%{recurrence: "monthly", weekday: day, month_week: week} = l) do
    ordinal =
      %{1 => "First", 2 => "Second", 3 => "Third", 4 => "Fourth", 5 => "Fifth", -1 => "Last"}[
        week
      ]

    join(["#{ordinal} #{Enum.at(@days, day - 1)} of the month", time_line(l)])
  end

  def pattern(_), do: nil

  @doc "Short series label for cards: Weekly, Monthly, or Multiple dates for a set of listed dates."
  def series_label(%{schedule_kind: "recurring", recurrence: "weekly"}), do: "Weekly"
  def series_label(%{schedule_kind: "recurring", recurrence: "monthly"}), do: "Monthly"
  def series_label(%{schedule_kind: "recurring", occurrences: [_, _ | _]}), do: "Multiple dates"
  def series_label(_), do: nil

  def common_timezone(l) do
    case Enum.uniq(Enum.map(l.occurrences, & &1.timezone)) do
      [tz] -> tz || "Timezone not confirmed"
      _ -> nil
    end
  end

  @doc "The discovery sort date, only presented as a course session when confirmed."
  def card_date(l, today) do
    date = l.discovery_date || ClimbOntario.Catalogue.relevant_date(l, {today, nil})

    if l.schedule_kind == "course" and not Enum.any?(l.occurrences, &(&1.date == date)),
      do: nil,
      else: date
  end

  @doc "Use the exact session selected by discovery, including its distance predicate."
  def card_session(_, nil), do: nil

  def card_session(%{discovery_occurrence_id: id} = l, _) when not is_nil(id),
    do: Enum.find(l.occurrences, &(&1.id == id))

  def card_session(l, date) do
    l.occurrences
    |> Enum.filter(&(&1.date == date))
    |> Enum.min_by(&ClimbOntario.Catalogue.Occurrence.sort_key/1, fn -> nil end)
  end

  def gym_website(%{website: website}),
    do: if(ClimbOntario.Catalogue.Listing.valid_url?(website), do: website)

  @doc "A map pin for the place, by address: area coordinates are never entrance pins."
  def map_url(%{street_address: address, city: city})
      when is_binary(address) and address != "" and is_binary(city) and city != "" do
    query = URI.encode_www_form("#{address}, #{city}, Ontario")
    "https://www.google.com/maps/search/?api=1&query=#{query}"
  end

  def map_url(_), do: nil

  @doc "Omit title-only descriptions in presentation, preserving source text."
  def summary(l) do
    text = l.summary || ""
    if normalize_copy(text) in ["", normalize_copy(l.title)], do: nil, else: text
  end

  defp normalize_copy(text) do
    text |> String.downcase() |> String.replace(~r/[^\p{L}\p{N}]+/u, " ") |> String.trim()
  end

  def session_lines(l), do: Enum.map(session_rows(l, nil), & &1.text)

  @doc "All known sessions, with date-based past/next states; patterns never add dates."
  def session_rows(l, today) do
    common_place = ClimbOntario.Catalogue.Listing.display_location(l)
    timezone = common_timezone(l)

    sessions =
      Enum.sort_by(l.occurrences, &{Date.to_gregorian_days(&1.date), &1.start_time, &1.cohort})

    next = if today, do: Enum.find_index(sessions, &(Date.compare(&1.date, today) != :lt))

    confirmed =
      sessions
      |> Enum.with_index()
      |> Enum.map(fn {o, index} ->
        place = ClimbOntario.Catalogue.Listing.location(l, o)

        text =
          join([
            o.cohort,
            date_with_year(o.date),
            if(timezone,
              do: time_range(o.start_time, o.end_time) || "Time not announced",
              else: time_line(o)
            ),
            if(place != common_place, do: venue_line(place)),
            if(place != common_place, do: place.street_address)
          ])

        state =
          cond do
            today && Date.compare(o.date, today) == :lt -> :past
            index == next -> :next
            true -> :future
          end

        %{text: text, state: state, occurrence: o}
      end)

    unknown = l.cohorts -- Enum.map(l.occurrences, & &1.cohort)

    confirmed ++
      Enum.map(
        unknown,
        &%{text: "#{&1} · Dates and times not confirmed", state: :unknown, occurrence: nil}
      )
  end

  defp join(parts), do: parts |> Enum.reject(&(&1 in [nil, ""])) |> Enum.join(" · ")

  def updated(%Date{} = d), do: "#{Enum.at(@months, d.month - 1)} #{d.day}, #{d.year}"
end
