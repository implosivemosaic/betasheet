defmodule ClimbOntario.Catalogue.KeywordTest do
  use ClimbOntario.DataCase, async: false
  import ClimbOntario.Fixtures
  alias ClimbOntario.Catalogue.{Keyword, Query}
  alias ClimbOntario.Catalogue

  test "normalized words, prefixes, small typos, short-term noise and AND across fields" do
    l =
      listing!(venue!(%{name: "Élan Climbing"}), %{
        title: "Boulder Night",
        summary: "Friendly coaching",
        location_kind: "offsite",
        offsite_name: "River Park"
      })

    for q <- [
          "ÉLAN",
          "elan",
          "boul",
          "bouldr",
          "boulxer",
          "river coaching",
          "night elan",
          "bo ni"
        ] do
      assert Keyword.matches?(l, q), q
    end

    for q <- ["cat", "bol", "bxxlder", "night swimming", "zz"] do
      refute Keyword.matches?(l, q), q
    end
  end

  test "keyword only filters; chronology wins over exactness and unscheduled legacy is ignored" do
    v = venue!()
    listing!(v, %{title: "Bouldering", start_date: ~D[2026-10-01]})
    listing!(v, %{title: "Boulder", start_date: ~D[2026-10-10]})

    hidden =
      listing!(v, %{title: "Boulder undated", schedule_kind: "unscheduled", start_date: nil})

    q = Query.from_params(%{"q" => "boulder", "unscheduled" => "1"}, ~D[2026-09-01])
    assert Enum.map(Catalogue.search(q).dated, & &1.title) == ["Bouldering", "Boulder"]
    assert Catalogue.search(q).total == 2
    assert Catalogue.get_listing(hidden.id)
    refute Elixir.Keyword.has_key?(Query.to_params(q), :unscheduled)

    for bad <- [%{}, ["x"], String.duplicate("a", 101), "!!!"] do
      assert Query.from_params(%{"q" => bad}, ~D[2026-09-01]).keyword == nil
    end
  end
end
