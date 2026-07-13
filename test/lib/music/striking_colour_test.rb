require "test_helper"

# The one colour a record is worth wearing.
class Music::StrikingColourTest < ActiveSupport::TestCase
  include Sleeves

  BLACK = "#101010".freeze
  WHITE = "#f5f5f5".freeze
  RED = "#c8102e".freeze

  # Figure 8: black, white and red. Black and white are not colours anybody
  # would paint an app with, so the red is the only thing on the sleeve with
  # anything to say.
  test "the colour of a black, white and red sleeve is the red" do
    colour = Music::StrikingColour.of(sleeve(BLACK => 0.5, WHITE => 0.25, RED => 0.25))

    assert_in_delta Colour.hex(RED).hue, colour.hue, 5
  end

  # Not the commonest colour: the most striking one. Half this sleeve is a muddy
  # olive and only a fifth of it is orange, but nobody looking at it would say it
  # was an olive record.
  test "the striking colour is not simply the one there is most of" do
    olive = "#6b6a3a" # a lot of it, and dull
    orange = "#ff7a18" # less of it, and loud

    colour = Music::StrikingColour.of(sleeve(olive => 0.6, BLACK => 0.2, orange => 0.2))

    assert_in_delta Colour.hex(orange).hue, colour.hue, 8
  end

  # Some records really are black and white. Rather than dig a colour out of a
  # sleeve that has none, the extractor says so, and the app keeps its own.
  test "a sleeve with no colour on it has none to give" do
    assert_nil Music::StrikingColour.of(sleeve(BLACK => 0.4, "#808080" => 0.3, WHITE => 0.3))
  end

  # A cover can be missing, truncated, or a JPEG in name only — the NAS is full
  # of files somebody's ripper wrote in 2006. None of that is worth an exception
  # on the way to picking a colour.
  test "a cover that cannot be read has no colour either" do
    assert_nil Music::StrikingColour.of("/nowhere/cover.jpg")
    assert_nil Music::StrikingColour.of(nil)
  end
end
