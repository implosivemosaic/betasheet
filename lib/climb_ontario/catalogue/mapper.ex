defmodule ClimbOntario.Catalogue.Mapper do
  @moduledoc """
  Pure translation from a research `events` row (map with string keys, joined to
  its gym and source URLs) into listing attributes. No I/O.
  """
  alias ClimbOntario.Catalogue.Text

  @type research_event :: %{required(String.t()) => term()}

  @doc "Translate one research event into listing attrs. `today` decides listed/schedule state."
  def to_listing(%{} = ev, venue, today \\ Date.utc_today(), editorial \\ %{}) do
    category = ev["category"] || ""

    title =
      ev["title"]
      |> Text.respace_digits()
      |> String.replace(~r/\s*[—–-]\s*\d{4}-\d{2}-\d{2}\s*$/u, "")
      |> String.trim()

    start_date = parse_date(ev["start_date"])
    end_date = parse_date(ev["end_date"])
    status = ev["status"]
    blob = blob(ev)
    kind = kind(category, title)
    schedule_kind = schedule_kind(status, category, start_date, end_date)

    %{
      source_event_id: ev["id"],
      venue_id: venue.id,
      slug: "#{ev["id"]}-#{Text.slugify(title)}",
      title: title,
      kind: kind,
      subkind: subkind(category, title),
      schedule_kind: schedule_kind,
      status: status,
      start_date: start_date,
      end_date: end_date,
      start_time: parse_time(ev["start_time"]),
      end_time: parse_time(ev["end_time"]),
      recurrence_text: Text.unmangle(ev["recurrence_text"]),
      price_text: Text.unmangle(ev["price_text"]),
      price_note: editorial["price_note"],
      price_short: Text.price_short(editorial["price_note"] || ev["price_text"]),
      summary: editorial["summary"] || Text.summary(ev["description"]),
      schedule_note: editorial["schedule_note"],
      ages: editorial["ages"],
      caveat: editorial["caveat"],
      details: Text.unmangle(ev["description"]),
      audience: audience(category, title, ev["description"] || ""),
      skill: skill(category, title, ev["description"] || ""),
      confidence: confidence(status, ev["notes"] || ""),
      registration_state: registration_state(blob),
      venue_note: venue_note(blob),
      organizer_url: organizer_url(ev, venue),
      source_urls: source_urls(ev),
      checked_at: parse_datetime(ev["checked_at"]),
      listed: listed?(status, schedule_kind, start_date, end_date, today)
    }
  end

  @doc "The four public kinds."
  def kind(category, title \\ "") do
    cond do
      category =~ ~r/competition|league|tryout/ ->
        "competition"

      category =~ ~r/camp/ ->
        "camp"

      category =~
          ~r/social|community|meetup|night|open_house|celebration|demonstration|governance|family_climbing|accessible|adaptive|staff_assisted|kids_session|special|outdoor|drytooling/ ->
        "social"

      title =~ ~r/\b(comp|competition|league|tryouts?)\b/i ->
        "competition"

      true ->
        "class"
    end
  end

  @doc "Human label for the badge, more specific than kind."
  def subkind(category, title) do
    cond do
      category =~ ~r/tryout/ ->
        "Team tryout"

      category =~ ~r/league/ ->
        "League"

      category =~ ~r/ninja_competition/ ->
        "Ninja competition"

      title =~ ~r/\bOCF\b/ ->
        "OCF sanctioned"

      category =~ ~r/competition/ ->
        "Competition"

      category =~ ~r/day_camp|pa_day/ or title =~ ~r/PA Day/i ->
        "Day camp"

      category =~ ~r/camp/ ->
        "Camp"

      category =~ ~r/open_house/ ->
        "Open house"

      category =~ ~r/meetup|community_climb|community_night|community_session|social/ ->
        "Meetup"

      category =~ ~r/adaptive|accessible|staff_assisted/ ->
        "Adaptive session"

      category =~ ~r/family/ ->
        "Family climb"

      category =~ ~r/community_offer/ ->
        "Special offer"

      category =~ ~r/community|celebration|demonstration|governance|special|outdoor|drytooling/ ->
        "Community event"

      category =~ ~r/intro|lesson/ ->
        "Intro lesson"

      category =~ ~r/clinic|workshop/ ->
        "Clinic"

      category =~ ~r/course/ ->
        "Course"

      category =~ ~r/team/ ->
        "Team program"

      category =~ ~r/coaching|training/ ->
        "Training"

      category =~ ~r/yoga|fitness|running|aerial|ninja_program/ ->
        "Fitness"

      category =~ ~r/program|class/ ->
        "Program"

      true ->
        "Program"
    end
  end

  @doc "How the thing is scheduled."
  def schedule_kind(status, category, start_date, end_date) do
    span = if start_date && end_date, do: Date.diff(end_date, start_date), else: 0

    cond do
      status == "recurring" -> "recurring"
      status == "needs_schedule" or is_nil(start_date) -> "unscheduled"
      category =~ ~r/course|program|series|team|training|club/ and span > 3 -> "course"
      span > 3 -> "course"
      span > 0 -> "multi_day"
      true -> "one_off"
    end
  end

  @doc "Who it's for. Tags from category, title and description."
  def audience(category, title, description) do
    t = title <> " " <> String.slice(description, 0, 300)

    [
      {"youth",
       category =~ ~r/youth|kids|day_camp|camp|team_tryout|tryout|kinder/ or
         t =~
           ~r/\b(kids?|youth|teens?|junior|lil|kinder|U1[1357]|U19|U21|E\/D\/C|D\/C|ages? ?\d{1,2}\s?[-–]\s?1\d)\b/i},
      {"adult",
       category =~ ~r/adult/ or t =~ ~r/\b(adults?|senior selection|\bSR\b|19\+|18\+)\b/i},
      {"family", category =~ ~r/family/ or t =~ ~r/\b(family|families|parent)\b/i},
      {"adaptive",
       category =~ ~r/adaptive|accessible|staff_assisted/ or
         t =~ ~r/\b(adaptive|para|accessible)\b/i},
      {"women", t =~ ~r/\b(women'?s?|ladies)\b/i},
      {"queer", t =~ ~r/\b(queer|lgbtq\+?|2slgbtq\+?)\b/i}
    ]
    |> Enum.filter(fn {_, hit} -> hit end)
    |> Enum.map(&elem(&1, 0))
    |> case do
      [] -> if category =~ ~r/competition/, do: ["adult"], else: []
      tags -> tags
    end
  end

  def skill(category, title, description) do
    t = title <> " " <> String.slice(description, 0, 300)

    cond do
      category =~ ~r/intro/ or
          t =~ ~r/\b(intro|101|beginner|first[- ]time|get into|learn to|no experience)\b/i ->
        "beginner"

      t =~ ~r/\b(advanced|experienced|competitive|elite|prerequisite)\b/i ->
        "experienced"

      true ->
        nil
    end
  end

  def confidence("tentative", _notes), do: "tentative"

  def confidence(_status, notes) do
    if notes =~ ~r/conflict|unverified|uncorroborated|inferred|unconfirmed|not yet publish/i,
      do: "check",
      else: "confirmed"
  end

  def registration_state(blob) do
    cond do
      blob =~ ~r/sold ?out|\bfull\b|booking closed|registration closed|waitlist/i ->
        "full"

      blob =~ ~r/registration opens|tickets? not yet|not available yet|opens? \w+ \d/i ->
        "opens_later"

      blob =~ ~r/\bavailable\b|register|book|tickets?/i ->
        "open"

      true ->
        "unknown"
    end
  end

  def venue_note(blob) do
    cond do
      blob =~ ~r/off-?site|offsite/i ->
        "Held offsite; check the organizer for the venue"

      blob =~ ~r/multi-?venue|multiple venues|several gyms|across \w+ gyms/i ->
        "Multiple venues; check the organizer for locations"

      blob =~ ~r/venue tba|host tba|location tba/i ->
        "Venue to be announced"

      true ->
        nil
    end
  end

  @doc "Where to send someone who wants to go: registration first, then the organizer's page."
  def organizer_url(ev, venue) do
    ev["registration_url"] ||
      first_source(ev, ["website", "registration", "booking"]) ||
      venue.website
  end

  def source_urls(ev) do
    (ev["sources"] || [])
    |> Enum.filter(&(&1["platform"] in ["website", "instagram", "facebook", "registration"]))
    |> Enum.map(& &1["url"])
    |> Enum.uniq()
    |> Enum.take(3)
  end

  @doc "Listed = should appear in default results and searches. Past things keep their page but drop out."
  def listed?(status, schedule_kind, start_date, end_date, today) do
    cond do
      status == "cancelled" -> false
      status == "past" -> false
      schedule_kind == "recurring" -> is_nil(end_date) or Date.compare(end_date, today) != :lt
      schedule_kind == "unscheduled" -> true
      is_nil(start_date) -> false
      true -> Date.compare(end_date || start_date, today) != :lt
    end
  end

  defp first_source(ev, platforms) do
    Enum.find_value(platforms, fn p ->
      Enum.find_value(ev["sources"] || [], fn s -> if s["platform"] == p, do: s["url"] end)
    end)
  end

  defp blob(ev) do
    [ev["recurrence_text"], ev["notes"], ev["price_text"], ev["description"]]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp parse_date(nil), do: nil

  defp parse_date(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_time(nil), do: nil

  defp parse_time(s) do
    case Time.from_iso8601(String.pad_trailing(s, 8, ":00") |> String.slice(0, 8)) do
      {:ok, t} -> t
      _ -> nil
    end
  end

  defp parse_datetime(s) do
    case DateTime.from_iso8601(s || "") do
      {:ok, dt, _} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
