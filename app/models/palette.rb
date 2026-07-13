# The look of a record, taken from one colour.
#
# A sleeve is not lit for a screen. Its most striking colour may be the red of a
# shadow, too dark to glow on a dark panel; or a wash so faint it would read as
# grey; or a neon that hurts to sit next to. So the hue — which is the record's,
# and the whole point — is left exactly as it was, and only the manners are
# argued with: held vivid enough to read as an accent, and light enough to lift
# off the panels without going pale.
#
# Everything the app wears comes off this one colour. Nothing else is chosen.
class Palette
  # Apple Music's red, worn when nothing is playing — and when what is playing is
  # a sleeve with no colour on it at all.
  STANDING = "#fa2d48".freeze

  # Vivid enough to read as an accent, quiet enough to sit beside text.
  VIVIDNESS = (0.55..0.92)
  # Light enough to glow on the dark panels, dark enough to hold a white label.
  BRIGHTNESS = (0.50..0.62)
  # How much lighter the same colour goes under the cursor.
  LIFT = 0.09
  CEILING = 0.72
  # Past this, an accent is bright enough that white text on it stops being text.
  TOO_BRIGHT_FOR_WHITE = 0.42

  # How much of the accent survives in the glow under a button, and in the wash
  # of light behind the whole room.
  GLOW = 0.55
  WASH = 0.14

  def self.for(seed)
    new(seed || Colour.hex(STANDING))
  end

  def self.standing
    self.for(nil)
  end

  def initialize(seed)
    @seed = seed
  end

  def accent
    legible.to_hex
  end

  def accent_bright
    legible.with(
      saturation: legible.saturation,
      lightness: [ legible.lightness + LIFT, CEILING ].min
    ).to_hex
  end

  def on_accent
    legible.luminance > TOO_BRIGHT_FOR_WHITE ? Colour::BLACK : Colour::WHITE
  end

  # The bead of light under the Play button.
  def glow
    legible.to_rgba(GLOW)
  end

  # The light in the corners of the room, behind everything.
  def wash
    legible.to_rgba(WASH)
  end

  # The whole handover. The browser is given the finished look and has nothing
  # left to work out: every colour decision in this app was made in this object.
  def to_h
    {
      "--color-accent": accent,
      "--color-accent-bright": accent_bright,
      "--color-on-accent": on_accent,
      "--gel-glow": glow,
      "--ambient-tint": wash
    }
  end

  private

  def legible
    @legible ||= @seed.with(
      saturation: @seed.saturation.clamp(VIVIDNESS.begin, VIVIDNESS.end),
      lightness: @seed.lightness.clamp(BRIGHTNESS.begin, BRIGHTNESS.end)
    )
  end
end
