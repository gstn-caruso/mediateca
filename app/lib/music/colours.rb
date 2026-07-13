module Music
  # The colour of every record that has none. Asked for once: the scope is the
  # records nobody has looked at yet, so a second run looks at nobody.
  #
  # A sleeve that turns out to be black and white is written down as nothing, and
  # so gets read again next time — which costs a couple of milliseconds and means
  # a better scan of the cover, dropped onto the NAS later, is picked up.
  class Colours
    def collect(albums = Album.where(accent: nil))
      albums.find_each { |album| paint(album) }
    end

    private

    def paint(album)
      colour = Music::StrikingColour.of(album.cover_path)

      album.update!(accent: colour.to_hex) if colour
    end
  end
end
