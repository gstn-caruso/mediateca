module Music
  # Somebody else's idea of a song, found on this disk.
  #
  # Last.fm knows a song as two strings, and so, near enough, does a disk. This is
  # what stands between them — and it belongs to neither of them, which is why it
  # lives here rather than in either one's namespace.
  #
  # It asks the library under both names a song can go by: the sleeve it belongs
  # to, and the credit written on the file. A duet is scrobbled under whoever sang
  # it, not under whoever owns the record — and a compilation is scrobbled under
  # nobody who appears on its cover.
  #
  # The match is deliberately blunt: case is nothing, accents are nothing, and an
  # ampersand, a dash and a comma are all just a gap. "Café Tacvba" and "cafe
  # tacvba" are one band, and being right about that matters more than being
  # clever about anything else.
  class Lookup
    def find(artist:, track:)
      songs[key(artist, track)]
    end

    private

    def songs
      @songs ||= Track.joins(album: :artist)
                      .pluck(:id, :title, :artist, "artists.name")
                      .each_with_object({}) do |(id, title, credit, sleeve), known|
        [ credit, sleeve ].compact_blank.uniq.each { known[key(it, title)] ||= id }
      end
    end

    def key(artist, track)
      [ plainly(artist), plainly(track) ]
    end

    def plainly(text)
      I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
