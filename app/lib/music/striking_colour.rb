# The one colour a record is worth wearing.
#
# Not the commonest colour on the sleeve — that is very often black, and a record
# is not black. The most striking one: the colour that, of everything printed
# there, is what you would answer if somebody asked what colour that record is.
#
# So every pixel that is a colour at all — the blacks, the whites and the greys
# have no hue anybody would paint an app with — casts a vote, and votes are
# weighted by how vivid they are. The votes are counted by family (reds together,
# blues together, twelve families around the wheel), the loudest family wins, and
# its average, pulled toward its most vivid members, is the record's colour.
#
# A sleeve that is genuinely black and white has no colour to give, and says so.
class Music::StrikingColour
  Vote = Data.define(:colour, :weight)

  # Big enough that a splash of colour still lands in it, small enough that
  # reading the whole sleeve costs a couple of milliseconds.
  THUMBNAIL = 64

  # What is not a colour: greys, shadows and glare. A sleeve is mostly these.
  GREY = 0.2
  SHADOW = 0.12
  GLARE = 0.9

  # Twelve families of 30° each. Wide enough that a gradient's reds count as one
  # red, narrow enough that a red and an orange are not confused for each other.
  FAMILIES = 12
  FAMILY = 360 / FAMILIES

  def self.of(cover)
    new(cover).colour
  end

  def initialize(cover)
    @cover = cover
  end

  def colour
    return if votes.empty?

    average(loudest_family)
  end

  private

  def loudest_family
    votes.group_by { |vote| (vote.colour.hue / FAMILY).floor % FAMILIES }
         .values
         .max_by { |family| family.sum(&:weight) }
  end

  # The vivid members of a family pull its average toward themselves, so a red
  # sleeve with one bright red stripe comes back that stripe's red, not a red
  # averaged with everything faded around it.
  def average(family)
    weight = family.sum(&:weight)
    channels = %i[red green blue].map do |channel|
      family.sum { |vote| vote.colour.public_send(channel) * vote.weight } / weight
    end

    Colour.rgb(*channels)
  end

  def votes
    @votes ||= pixels.filter_map do |red, green, blue|
      colour = Colour.rgb(red, green, blue)

      Vote.new(colour, colour.saturation) if a_colour_at_all?(colour)
    end
  end

  def a_colour_at_all?(colour)
    colour.saturation >= GREY && colour.lightness.between?(SHADOW, GLARE)
  end

  # A cover can be missing, truncated, or a JPEG in name only — the NAS is full
  # of files somebody's ripper wrote in 2006, and none of that is worth an
  # exception on the way to picking a colour. A missing ffmpeg is a different
  # matter, and is left to be raised: that one is our fault, not the file's.
  def pixels
    return [] if @cover.blank?

    Ffmpeg.new.pixels(@cover, size: THUMBNAIL)
  rescue Ffmpeg::Unreadable
    []
  end
end
