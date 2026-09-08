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
            audience: [],
            unscheduled: false,
            today: nil

  def whens, do: @whens
  def audiences, do: @audiences
  def default_km, do: @default_km

  @doc "Parse URL params. `today` is the local date in Toronto."
  def from_params(params, today) do
    near_text = blank_to_nil(params["near"])

    %__MODULE__{
      near_text: near_text,
      near: resolve(near_text),
      radius_km: int(params["km"], @default_km),
      kinds: list(params["kind"]) |> Enum.filter(&(&1 in ClimbOntario.Catalogue.Listing.kinds())),
      when: if(params["when"] in @whens, do: params["when"], else: "all"),
      audience: list(params["for"]) |> Enum.filter(&(&1 in @audiences)),
      unscheduled: params["unscheduled"] in ["1", "true"],
      today: today
    }
  end

  @doc "Back to URL params, omitting defaults so links stay short."
  def to_params(%__MODULE__{} = q) do
    [
      near: q.near_text,
      kind: join(q.kinds),
      when: if(q.when != "all", do: q.when),
      for: join(q.audience),
      km: if(q.radius_km != @default_km, do: q.radius_km),
      unscheduled: if(q.unscheduled, do: "1")
    ]
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

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

  defp list(nil), do: []

  defp list(s) when is_binary(s),
    do: s |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

  defp list(_), do: []
  defp join([]), do: nil
  defp join(l), do: Enum.join(l, ",")

  defp blank_to_nil(s) when is_binary(s),
    do: if(String.trim(s) == "", do: nil, else: String.trim(s))

  defp blank_to_nil(_), do: nil

  defp int(s, d) when is_binary(s) do
    case Integer.parse(s) do
      {n, _} when n > 0 and n <= 500 -> n
      _ -> d
    end
  end

  defp int(_, d), do: d
end
