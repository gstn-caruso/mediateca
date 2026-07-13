# A colour, and the three ways of looking at one that this app needs.
#
# Hex, because that is what CSS listens to. Hue, saturation and lightness,
# because that is where a colour can be argued with: a sleeve's red may be too
# dark to glow on a panel or too washed out to read as an accent, and both of
# those are fixable without turning it into another colour. And luminance —
# brightness as an eye actually weighs it, greens counting for far more than
# blues — because that is what decides whether white or black can be written on
# top of it.
#
# The hue is the identity of a colour. Saturation and lightness are its manners.
class Colour
  BLACK = "#0a0a0a".freeze
  WHITE = "#ffffff".freeze

  attr_reader :red, :green, :blue

  def self.hex(value)
    new(*value.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) })
  end

  def self.rgb(red, green, blue)
    new(red, green, blue)
  end

  def self.hsl(hue, saturation, lightness)
    chroma = (1 - (2 * lightness - 1).abs) * saturation
    second = chroma * (1 - ((hue / 60.0) % 2 - 1).abs)
    floor = lightness - chroma / 2

    red, green, blue = case hue
    when 0...60 then [ chroma, second, 0 ]
    when 60...120 then [ second, chroma, 0 ]
    when 120...180 then [ 0, chroma, second ]
    when 180...240 then [ 0, second, chroma ]
    when 240...300 then [ second, 0, chroma ]
    else [ chroma, 0, second ]
    end

    new(*[ red, green, blue ].map { |channel| (channel + floor) * 255 })
  end

  def initialize(red, green, blue)
    @red, @green, @blue = red, green, blue
  end

  def hue
    return 0 if span.zero?

    degrees = case high
    when scaled(red) then (scaled(green) - scaled(blue)) / span + (green < blue ? 6 : 0)
    when scaled(green) then (scaled(blue) - scaled(red)) / span + 2
    else (scaled(red) - scaled(green)) / span + 4
    end

    degrees * 60
  end

  def saturation
    return 0 if span.zero?

    lightness > 0.5 ? span / (2 - high - low) : span / (high + low)
  end

  def lightness
    (high + low) / 2
  end

  # WCAG relative luminance: the eye's own weighting of the three channels, each
  # one straightened out of the gamma curve the screen bends it into first.
  def luminance
    0.2126 * straightened(red) + 0.7152 * straightened(green) + 0.0722 * straightened(blue)
  end

  def with(saturation:, lightness:)
    self.class.hsl(hue, saturation, lightness)
  end

  def to_hex
    "#" + [ red, green, blue ].map { |channel| channel.round.clamp(0, 255).to_s(16).rjust(2, "0") }.join
  end
  alias_method :to_s, :to_hex

  # The same colour, seen through something: a glow under a button, a light in
  # the corner of the room.
  def to_rgba(alpha)
    "rgba(#{red.round}, #{green.round}, #{blue.round}, #{alpha})"
  end

  def ==(other)
    other.is_a?(Colour) && to_hex == other.to_hex
  end

  private

  # Hue, saturation and lightness all read the same three numbers: the brightest
  # channel, the dimmest, and how far apart they are. On a 0-to-1 scale, because
  # that is the scale every one of those formulas is written for.
  def scaled(channel) = channel / 255.0
  def high = scaled([ red, green, blue ].max)
  def low = scaled([ red, green, blue ].min)
  def span = high - low

  def straightened(channel)
    value = channel / 255.0

    value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
  end
end
