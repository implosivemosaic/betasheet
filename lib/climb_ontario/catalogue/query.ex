defmodule ClimbOntario.Catalogue.Query do
  @moduledoc "What the visitor asked for. Built from URL params; serialised back to them."
  alias ClimbOntario.Geo

  @whens ~w(all weekend week month)
  @audiences ClimbOntario.Catalogue.Listing.audiences()
  @default_km 40

  defstruct near_text: nil,
            near: nil,
            radius_km: @default_km,
            kinds: [],
            when: "all",
            from: nil,
            to: nil,
            days: [],
            audience: [],
            keyword: nil,
            page: 1,
            today: nil

  def whens, do: @whens
  def audiences, do: @audiences
  def default_km, do: @default_km

  @doc "Parse URL params. `today` is the local date in Toronto."
  def from_params(params, today) do
    near_text = blank_to_nil(params["near"])
    {from, to} = range(params, today)

    %__MODULE__{
      near_text: near_text,
      near: resolve(near_text),
      radius_km: int(params["km"], @default_km),
      kinds:
        list(params["kind"])
        |> Enum.filter(&(&1 in ClimbOntario.Catalogue.Listing.discovery_kinds())),
      from: from,
      to: to,
      days:
        list(params["days"])
        |> Enum.filter(&(&1 in ~w(1 2 3 4 5 6 7)))
        |> Enum.map(&String.to_integer/1)
        |> Enum.uniq()
        |> Enum.sort(),
      audience: list(params["for"]) |> Enum.filter(&(&1 in @audiences)),
      keyword: keyword(params["q"]),
      page: page(params["page"]),
      today: today
    }
  end

  @doc "Back to URL params, omitting defaults so links stay short."
  def to_params(%__MODULE__{} = q) do
    [
      near: q.near_text,
      kind: join(q.kinds),
      from: q.from && Date.to_iso8601(q.from),
      to: q.to && Date.to_iso8601(q.to),
      days: if(q.days != [], do: Enum.join(q.days, ",")),
      for: join(q.audience),
      km: if(q.radius_km != @default_km, do: q.radius_km),
      q: q.keyword,
      page: if(q.page > 1, do: q.page)
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  def dated_filter?(q), do: q.from != nil or q.to != nil or q.days != []

  defp range(params, today) do
    if Map.has_key?(params, "from") or Map.has_key?(params, "to") do
      from = date(params["from"])
      to = date(params["to"])

      if from == :invalid or to == :invalid or (from && to && Date.compare(from, to) == :gt),
        do: {nil, nil},
        else: {from, to}
    else
      if params["when"] in ~w(week weekend month),
        do: ClimbOntario.Catalogue.window(params["when"], today),
        else: {nil, nil}
    end
  end

  defp date(s) when s in [nil, ""], do: nil

  defp date(s) when is_binary(s) and byte_size(s) == 10 do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> :invalid
    end
  end

  defp date(_), do: :invalid

  def toggle_kind(q, kind), do: %{q | kinds: toggle(q.kinds, kind)}
  def toggle_audience(q, a), do: %{q | audience: toggle(q.audience, a)}

  defp toggle(list, item), do: if(item in list, do: List.delete(list, item), else: list ++ [item])

  defp resolve(nil), do: nil

  defp resolve(text) do
    case Geo.resolve(text) do
      {:ok, point} -> point
      :error -> nil
    end
  end

  # Reject malformed/oversized input; punctuation-only input is equivalent to blank.
  defp keyword(s) when is_binary(s) and byte_size(s) <= 400 do
    text = String.trim(s)
    if String.length(text) <= 100 and ClimbOntario.Catalogue.Keyword.tokens(text) != [], do: text
  end

  defp keyword(_), do: nil

  defp list(nil), do: []

  defp list(s) when is_binary(s),
    do: s |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

  defp list(_), do: []
  defp join([]), do: nil
  defp join(l), do: Enum.join(l, ",")

  defp blank_to_nil(s) when is_binary(s),
    do: if(String.trim(s) == "", do: nil, else: String.trim(s))

  defp blank_to_nil(_), do: nil

  # URL depth is deliberately bounded; malformed/extreme inputs reset to the first batch.
  defp page(s) when is_binary(s) and byte_size(s) <= 2 do
    case Integer.parse(s) do
      {n, ""} when n in 1..50 -> n
      _ -> 1
    end
  end

  defp page(_), do: 1

  defp int(s, d) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} when n > 0 and n <= 500 -> n
      _ -> d
    end
  end

  defp int(_, d), do: d
end
