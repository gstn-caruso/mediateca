# Something the app can read a colour off, and then wear.
#
# What is coloured has a picture, and the picture is where the colour comes from.
# Nothing here knows which picture — a record would say its sleeve and an artist
# their photograph, and neither answer belongs in the reading of it.
module Coloured
  extend ActiveSupport::Concern

  included do
    # Nobody has read these yet. Reading a picture is not free, so a second run
    # reads nobody — except whatever turned out to have no colour at all, which
    # is asked again in case a better picture has landed since.
    scope :uncoloured, -> { where(accent: nil) }
  end

  # The look this hands the app, all of it off the one striking colour on its
  # picture. Something with no colour of its own hands over the app's standing red.
  def palette
    Palette.for(accent&.then { |hex| Colour.hex(hex) })
  end
end
