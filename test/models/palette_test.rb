require "test_helper"

# One colour off the sleeve decides the rest. These are the rules that turn it
# into a look the app can actually wear: the accent, the brighter one it goes to
# under the cursor, and what colour of text can sit on top of them.
class PaletteTest < ActiveSupport::TestCase
  test "the record's own colour is the accent" do
    palette = Palette.for(Colour.hex("#c8102e")) # the red on Figure 8

    assert_in_delta 350.2, Colour.hex(palette.accent).hue, 1,
      "the accent turned into another colour on its way out of the sleeve"
  end

  # A sleeve is not lit for a screen. Its red may be the red of a shadow, and an
  # accent that dark disappears into the dark panels it has to glow on.
  test "a colour too dark to glow is lifted until it does" do
    palette = Palette.for(Colour.hsl(350, 0.85, 0.18))

    assert_in_delta 0.50, Colour.hex(palette.accent).lightness, 0.01
  end

  test "a colour too light to hold its own is brought down" do
    palette = Palette.for(Colour.hsl(350, 0.85, 0.95))

    assert_in_delta 0.62, Colour.hex(palette.accent).lightness, 0.01
  end

  # Something nearly grey is not an accent. If it is the most striking thing on
  # the sleeve, the sleeve is drab — and the app still has to be legible.
  test "a colour too washed out to read as an accent is made vivid enough" do
    palette = Palette.for(Colour.hsl(210, 0.10, 0.55))

    assert_in_delta 0.55, Colour.hex(palette.accent).saturation, 0.01
  end

  test "a colour loud enough to hurt is held back" do
    palette = Palette.for(Colour.hsl(120, 1.0, 0.55))

    assert_in_delta 0.92, Colour.hex(palette.accent).saturation, 0.01
  end

  # The hover colour is the same colour with the light turned up, not a second
  # colour that happens to look related.
  test "the brighter accent is the accent, brighter" do
    palette = Palette.for(Colour.hex("#c8102e"))

    accent, bright = Colour.hex(palette.accent), Colour.hex(palette.accent_bright)

    assert_in_delta accent.hue, bright.hue, 1
    assert_operator bright.lightness, :>, accent.lightness
  end

  # White reads on most accents. It does not read on a bright yellow, and the
  # label on the Play button is not somewhere to find that out.
  test "the label on the accent is whichever of white or black can be read" do
    assert_equal Colour::WHITE, Palette.for(Colour.hex("#c8102e")).on_accent
    assert_equal Colour::BLACK, Palette.for(Colour.hsl(50, 0.95, 0.6)).on_accent
  end

  # A sleeve with no colour on it — black, white, grey — has nothing to say, and
  # the app falls back to the red it wears when nothing is playing at all.
  test "a record with no colour of its own leaves the app in its standing red" do
    assert_equal Palette.standing.accent, Palette.for(nil).accent
  end

  # The glow under the Play button and the light in the corners of the room are
  # the same colour as the accent, only thinned — they are the accent seen
  # through something, not two more colours to keep in step by hand.
  test "the glow and the wash are the accent, thinned" do
    palette = Palette.for(Colour.hex("#c8102e"))
    accent = Colour.hex(palette.accent)
    channels = "#{accent.red.round}, #{accent.green.round}, #{accent.blue.round}"

    assert_equal "rgba(#{channels}, 0.55)", palette.glow
    assert_equal "rgba(#{channels}, 0.14)", palette.wash
  end

  # This is the whole handover: the browser is handed the finished look and has
  # nothing left to work out. Every colour decision in the app was made here.
  test "a palette is handed over as the properties the stylesheet reads" do
    assert_equal %w[--color-accent --color-accent-bright --color-on-accent --gel-glow --ambient-tint],
      Palette.for(Colour.hex("#c8102e")).to_h.keys.map(&:to_s)
  end
end
