defmodule ClimbOntario.Catalogue.MapperTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Catalogue.Mapper

  @venue %{id: 7, website: "https://gym.example"}
  @today ~D[2026-09-08]

  defp event(over \\ %{}) do
    Map.merge(
      %{
        "id" => 303,
        "gym_id" => 1,
        "title" => "OCF Boulder U11/ U13/ U15 — 2026-12-12",
        "category" => "competition",
        "status" => "scheduled",
        "start_date" => "2026-12-12",
        "end_date" => "2026-12-13",
        "start_time" => nil,
        "end_time" => nil,
        "timezone" => "America/Toronto",
        "recurrence_text" => nil,
        "registration_url" => "https://ocf.example/e",
        "price_text" => nil,
        "description" => "Official provincial youth event.",
        "notes" => "save-the-date detail not yet published",
        "checked_at" => "2026-09-07T23:49:00Z",
        "sources" => [%{"platform" => "website", "url" => "https://ocf.example/e"}]
      },
      over
    )
  end

  test "a sanctioned youth comp maps to competition / multi_day / youth / check" do
    l = Mapper.to_listing(event(), @venue, @today)
    assert l.kind == "competition"
    assert l.subkind == "OCF sanctioned"
    assert l.schedule_kind == "multi_day"
    assert l.audience == ["youth"]
    assert l.confidence == "check"
    assert l.title == "OCF Boulder U11/ U13/ U15"
    assert l.slug == "303-ocf-boulder-u11-u13-u15"
    assert l.organizer_url == "https://ocf.example/e"
    assert l.listed
  end

  test "a ten-week youth program is a class / course and flags full" do
    l =
      event(%{
        "id" => 287,
        "title" => "Lemurs Level 1 — Fall 2026",
        "category" => "youth_program",
        "start_date" => "2026-09-18",
        "end_date" => "2026-11-27",
        "start_time" => "18:15",
        "recurrence_text" => "10 actual Fridays. FULL and online booking closed.",
        "price_text" => "Website292.04CAD+tax",
        "description" => "Beginner development level for children born2018–2021.",
        "notes" => nil
      })
      |> Mapper.to_listing(@venue, @today)

    assert l.kind == "class"
    assert l.schedule_kind == "course"
    assert l.registration_state == "full"
    assert l.start_time == ~T[18:15:00]
    assert "youth" in l.audience
    assert l.skill == "beginner"
    assert l.confidence == "confirmed"
    assert l.details == "Beginner development level for children born 2018–2021."
  end

  test "recurring social with no dates stays listed; past one-off is unlisted but keeps a slug" do
    social =
      event(%{
        "id" => 28,
        "title" => "Women's Bouldering Night",
        "category" => "community_climb",
        "status" => "recurring",
        "start_date" => nil,
        "end_date" => nil,
        "notes" => nil,
        "description" => "Weekly bouldering night for women and non-binary climbers."
      })

    l = Mapper.to_listing(social, @venue, @today)
    assert l.kind == "social" and l.schedule_kind == "recurring" and l.listed
    assert l.audience == ["women"]

    past = event(%{"start_date" => "2026-08-01", "end_date" => nil, "status" => "scheduled"})
    p = Mapper.to_listing(past, @venue, @today)
    refute p.listed
    assert p.slug =~ "303-"
  end

  test "organizer link falls back to website source, then venue website" do
    no_reg = event(%{"registration_url" => nil})
    assert Mapper.to_listing(no_reg, @venue, @today).organizer_url == "https://ocf.example/e"
    bare = event(%{"registration_url" => nil, "sources" => []})
    assert Mapper.to_listing(bare, @venue, @today).organizer_url == "https://gym.example"
  end

  test "offsite note hides the venue assumption" do
    l =
      Mapper.to_listing(
        event(%{"notes" => "Confirmed at 175 Bloor St East, an offsite venue."}),
        @venue,
        @today
      )

    assert l.venue_note =~ "offsite"
  end
end
