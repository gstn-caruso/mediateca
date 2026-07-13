module Music
  # The colour of everything that has none. Asked for once: the scope is whoever
  # nobody has looked at yet, so a second run looks at nobody.
  #
  # A picture that turns out to be black and white is written down as nothing, and
  # so gets read again next time — which costs a couple of milliseconds and means
  # a better scan of the cover, dropped onto the NAS later, is picked up.
  class Colours
    # Records and the people who made them. Both wear a colour, both read it off
    # a picture, and neither is asked how.
    COLOURED = [ Album, Artist ].freeze

    def collect
      COLOURED.each { |kind| kind.uncoloured.find_each { |coloured| paint(coloured) } }
    end

    private

    def paint(coloured)
      colour = Music::StrikingColour.of(coloured.picture)

      coloured.update!(accent: colour.to_hex) if colour
    end
  end
end
