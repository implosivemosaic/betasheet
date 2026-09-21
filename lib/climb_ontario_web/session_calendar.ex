defmodule ClimbOntarioWeb.SessionCalendar do
  @moduledoc "One confirmed session as RFC 5545 text. No inferred times, duration or recurrence."
  alias ClimbOntario.Catalogue.Listing

  def exportable?(session), do: match?({:ok, _, _}, instants(session))

  def render(listing, session, page_url, now) do
    with {:ok, lines} <- event_lines(listing, session, page_url, now) do
      {:ok, document(lines, "Session")}
    end
  end

  @doc "The VEVENT lines for one session, or :error when its instants aren't confirmed."
  def event_lines(listing, session, page_url, now) do
    with {:ok, start, finish} <- instants(session) do
      place = Listing.location(listing, session)
      title = Enum.join(Enum.reject([listing.title, session.cohort], &is_nil/1), " · ")

      location =
        Enum.join(Enum.reject([place.name, place.street_address, place.city], &is_nil/1), ", ")

      {:ok,
       [
         "BEGIN:VEVENT",
         "UID:listing-#{listing.id}-session-#{session.id}@climb-ontario",
         "DTSTAMP:#{stamp(now)}",
         "DTSTART:#{stamp(start)}",
         if(finish, do: "DTEND:#{stamp(finish)}"),
         "SUMMARY:#{escape(title)}",
         "LOCATION:#{escape(location)}",
         "DESCRIPTION:#{escape("Original event: #{listing.link}\nBeta Sheet: #{page_url}")}",
         "URL:#{listing.link}",
         "END:VEVENT"
       ]
       |> Enum.reject(&is_nil/1)}
    end
  end

  @doc "Wrap event lines in a VCALENDAR; `name` is shown by clients that subscribe to the feed."
  def document(event_lines, product, name \\ nil) do
    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Beta Sheet//#{product}//EN",
      "CALSCALE:GREGORIAN",
      if(name, do: "X-WR-CALNAME:#{escape(name)}"),
      event_lines,
      "END:VCALENDAR"
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join("\r\n", &fold/1)
    |> Kernel.<>("\r\n")
  end

  @doc "Local start and end (or nil) of a session as DateTimes in its own zone, when confirmed."
  def local_instants(%{date: %Date{}, start_time: %Time{}, timezone: tz} = s)
      when is_binary(tz) do
    with {:ok, start, finish} <- instants(s) do
      {:ok, DateTime.shift_zone!(start, tz, Tzdata.TimeZoneDatabase),
       finish && DateTime.shift_zone!(finish, tz, Tzdata.TimeZoneDatabase)}
    end
  end

  def local_instants(_), do: :error

  defp instants(%{date: %Date{} = date, start_time: %Time{} = time, timezone: tz} = s)
       when is_binary(tz) do
    with {:ok, start} <- utc(date, time, tz),
         {:ok, finish} <- finish(date, s.end_time, tz),
         true <- is_nil(finish) or DateTime.compare(finish, start) == :gt do
      {:ok, start, finish}
    else
      _ -> :error
    end
  end

  defp instants(_), do: :error
  defp finish(_, nil, _), do: {:ok, nil}
  defp finish(date, time, tz), do: utc(date, time, tz)

  defp utc(date, time, tz) do
    # Ambiguous fall-back and nonexistent spring-forward times are not guessed.
    with {:ok, local} <- DateTime.new(date, time, tz, Tzdata.TimeZoneDatabase),
         {:ok, utc} <- DateTime.shift_zone(local, "Etc/UTC", Tzdata.TimeZoneDatabase) do
      {:ok, utc}
    else
      _ -> :error
    end
  end

  defp stamp(dt), do: dt |> DateTime.shift_zone!("Etc/UTC") |> Calendar.strftime("%Y%m%dT%H%M%SZ")

  defp escape(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(~r/\r\n|\r|\n/, "\\n")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u, "")
  end

  # 75 octets per physical line, including continuation space; preserve UTF-8.
  defp fold(line) do
    {parts, _} =
      Enum.reduce(String.codepoints(line), {[], 0}, fn char, {parts, size} ->
        if size + byte_size(char) > 75,
          do: {[parts, "\r\n ", char], 1 + byte_size(char)},
          else: {[parts, char], size + byte_size(char)}
      end)

    IO.iodata_to_binary(parts)
  end
end
