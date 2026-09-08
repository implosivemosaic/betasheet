defmodule ClimbOntario.Catalogue.TextTest do
  use ExUnit.Case, async: true
  alias ClimbOntario.Catalogue.Text

  test "unmangle re-spaces collapsed research prose" do
    assert Text.unmangle(
             "SixWednesdaysSeptember16,23,30/October7,14,21,2026. Allsixverified,AlexM. Fee $1,250."
           ) ==
             "Six Wednesdays September 16, 23, 30/October 7, 14, 21, 2026. Allsixverified, AlexM. Fee $1,250."
  end

  test "unmangle keeps grades, acronyms and money intact" do
    assert Text.unmangle("$196+HST for7weeks, U11 v5, OCF Boulder 5.10d") ==
             "$196+HST for 7 weeks, U11 v5, OCF Boulder 5.10d"
  end

  test "respace_digits leaves proper-noun casing and ordinals alone" do
    assert Text.respace_digits("15th Anniversary Party, 2nd edition") ==
             "15th Anniversary Party, 2nd edition"

    assert Text.respace_digits("RockHaus Meetup — September2026") ==
             "RockHaus Meetup — September 2026"
  end

  test "summary drops source dump lines and caps length" do
    desc =
      "OCF Boulder U11/ U13/ U15\nSaturday, December 12, 20269:00 a.m.\nReach Indoor Climbing\n212 Earl Stewart Dr\nOfficial provincial youth bouldering event. Athlete schedule to follow."

    assert Text.summary(desc) ==
             "OCF Boulder U11/ U13/ U15 Reach Indoor Climbing Official provincial youth bouldering event. Athlete schedule to follow."

    assert String.length(Text.summary(String.duplicate("word ", 100), 60)) <= 60
  end

  test "price_short picks the first amount or Free" do
    assert Text.price_short("CAD 29.99 plus tax per participant") == "$29.99"
    assert Text.price_short("$150/six-week series") == "$150"
    assert Text.price_short("Free") == "Free"
    assert Text.price_short("Free with day pass") == nil
    assert Text.price_short("Finals spectators free; competitor fee not published") == nil
    assert Text.price_short("Programme fee unpublished") == nil
  end

  test "slugify" do
    assert Text.slugify("Brawl in the Fall 2026 — Grand River Rocks!") ==
             "brawl-in-the-fall-2026-grand-river-rocks"
  end
end
