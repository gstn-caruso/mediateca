require "test_helper"

class ColourTest < ActiveSupport::TestCase
  # The red on the sleeve of Figure 8, which is where all of this started.
  SLEEVE_RED = Colour.rgb(200, 16, 46)

  test "a colour says itself the way CSS wants to hear it" do
    assert_equal "#c8102e", SLEEVE_RED.to_hex
  end

  test "a colour read back from its hex is the same colour" do
    assert_equal SLEEVE_RED.to_hex, Colour.hex("#c8102e").to_hex
  end

  test "where a colour sits on the wheel" do
    assert_in_delta 350.2, SLEEVE_RED.hue, 0.1
    assert_in_delta 0.85, SLEEVE_RED.saturation, 0.01
    assert_in_delta 0.42, SLEEVE_RED.lightness, 0.01
  end

  # Grey is the colour that has no colour: it sits at no hue, and saying it is
  # "at 0°" would be saying it is red. Nothing on a sleeve that comes back grey
  # should ever be mistaken for a colour worth painting the app with.
  test "a grey is at no hue at all" do
    grey = Colour.rgb(128, 128, 128)

    assert_equal 0, grey.saturation
    assert_equal 0, grey.hue
  end

  test "luminance runs from black to white" do
    assert_in_delta 0.0, Colour.rgb(0, 0, 0).luminance, 0.001
    assert_in_delta 1.0, Colour.rgb(255, 255, 255).luminance, 0.001
  end

  # Turning a colour up or down is not turning it into another colour: the hue
  # is the identity of it, and only how vivid and how light it is can be argued
  # with. This is the whole reason the app stopped warming hues.
  test "made more vivid or lighter, a colour keeps its hue" do
    lifted = SLEEVE_RED.with(saturation: 0.9, lightness: 0.5)

    assert_in_delta SLEEVE_RED.hue, lifted.hue, 0.5
    assert_in_delta 0.9, lifted.saturation, 0.01
    assert_in_delta 0.5, lifted.lightness, 0.01
  end
end
