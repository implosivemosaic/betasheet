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

  def when_line(%{schedule_kind: "recurring", occurrences: occ}, today)
      when is_list(occ) and occ != [] do
    next =
      occ
      |> Enum.map(& &1.date)
      |> Enum.filter(&(is_nil(today) or Date.compare(&1, today) != :lt))
      |> Enum.min(Date, fn -> nil end)

    if next, do: "Next #{date(next)}", else: "Ongoing"
  end

  def when_line(%{schedule_kind: "recurring"}, _), do: "Ongoing"
  def when_line(%{schedule_kind: "unscheduled"}, _), do: "Schedule not posted yet"

  def when_line(%{schedule_kind: "one_off", start_date: d, start_time: t}, _) do
    [date(d), time(t)] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")
  end

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

  @doc "Relative day hint: Today, Tomorrow, This weekend, or nil."
  def soon(%{schedule_kind: k, start_date: %Date{} = d}, today) when k in ~w(one_off multi_day) do
    case Date.diff(d, today) do
      0 -> "Today"
      1 -> "Tomorrow"
      n when n in 2..6 -> if Date.day_of_week(d) in [6, 7], do: "This weekend", else: nil
      _ -> nil
    end
  end

  def soon(_, _), do: nil

  @doc "Venue name plus city, unless the name already says the city."
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

  def kind_label("competition"), do: "Comps"
  def kind_label("social"), do: "Socials"
  def kind_label("class"), do: "Classes"
  def kind_label("camp"), do: "Camps"

  def audience_label("youth"), do: "Kids & youth"
  def audience_label("adult"), do: "Adults"
  def audience_label("family"), do: "Families"
  def audience_label("adaptive"), do: "Adaptive"
  def audience_label("women"), do: "Women"
  def audience_label("queer"), do: "Queer"

  def when_label("all"), do: "Anytime"
  def when_label("weekend"), do: "Weekend"
  def when_label("week"), do: "7 days"
  def when_label("month"), do: "Month"

  def updated(%Date{} = d), do: "#{Enum.at(@months, d.month - 1)} #{d.day}, #{d.year}"
end
