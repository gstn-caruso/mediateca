module Music
  # Reads what an audio file says about itself.
  #
  # Tag names are whatever the person who tagged the file typed: ALBUM,
  # album_artist, Track. They all mean the same thing, so the lookup ignores
  # case, and every alias for one idea is listed together.
  class Tags
    TITLE = %w[title].freeze
    ARTIST = %w[artist].freeze
    ALBUM_ARTIST = %w[album_artist albumartist].freeze
    ALBUM = %w[album].freeze
    YEAR = %w[date year originalyear originaldate].freeze
    GENRE = %w[genre].freeze
    TRACK = %w[track tracknumber].freeze
    DISC = %w[disc discnumber].freeze

    def initialize(ffprobe: ::Ffprobe.new)
      @ffprobe = ffprobe
    end

    def read(path)
      format = ffprobe.describe(path).fetch("format", {})
      tags = normalize(format["tags"])
      artist = value(tags, ARTIST)

      FileTags.new(
        title: value(tags, TITLE) || ::File.basename(path.to_s, ".*"),
        artist: artist,
        album_artist: value(tags, ALBUM_ARTIST) || artist,
        album: value(tags, ALBUM),
        year: year(tags),
        genre: value(tags, GENRE),
        track_no: number(tags, TRACK),
        disc_no: number(tags, DISC) || 1,
        duration: format["duration"]&.to_f
      )
    end

    private

    attr_reader :ffprobe

    def normalize(tags)
      (tags || {}).transform_keys(&:downcase)
    end

    def value(tags, names)
      names.filter_map { |name| tags[name] }.map(&:strip).find(&:present?)
    end

    # DATE is "2010" in one file and "2005-11-22" in the next.
    def year(tags)
      value(tags, YEAR)&.slice(/\d{4}/)&.to_i
    end

    # Track numbers travel as "3" or as "3/12".
    def number(tags, names)
      value(tags, names)&.slice(/\d+/)&.to_i
    end
  end
end
