defmodule ClimbOntarioWeb.Format do
  @moduledoc "Pure formatters for dates, times, distance and labels shown to visitors."

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  @days ~w(Mon Tue Wed Thu Fri Sat Sun)

  def date(nil), do: nil

  def date(%Date{} = d),
    do: "#{Enum.at(@days, Date.day_of_week(d) - 1)} #{Enum.at(@months, d.month - 1)} #{d.day}"

  def date_with_year(%Date{} = d), do: date(d) <> ", #{d.year}"

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
      do: "In progress · ends #{date(e)}",
      else: "Starts #{date(s)} · runs to #{date(e)}"
  end

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

  @doc "Price line: the published note; 'Free' only when admission is free and no note says more."
  def price(%{price_note: note}) when is_binary(note) and note != "", do: note
  def price(%{price_state: "admission_free"}), do: "Free"
  def price(_), do: nil

  def link_label("registration"), do: "Register with organizer"
  def link_label("event"), do: "View official event"
  def link_label(_), do: "Gym website"

  def distance(nil), do: nil
  def distance(km) when km < 1, do: "<1 km"
  def distance(km) when km < 10, do: "#{Float.round(km, 1)} km"
  def distance(km), do: "#{round(km)} km"

  def kind_label("competition"), do: "Competitions"
  def kind_label("social"), do: "Socials & meetups"
  def kind_label("class"), do: "Classes & clinics"
  def kind_label("camp"), do: "Camps"

  def audience_label("youth"), do: "Kids & youth"
  def audience_label("adult"), do: "Adults"
  def audience_label("family"), do: "Families"
  def audience_label("adaptive"), do: "Adaptive"
  def audience_label("women"), do: "Women"
  def audience_label("queer"), do: "Queer"

  def when_label("all"), do: "Anytime"
  def when_label("weekend"), do: "This weekend"
  def when_label("week"), do: "Next 7 days"
  def when_label("month"), do: "This month"

  def checked(%Date{} = d), do: date_with_year(d)
end
