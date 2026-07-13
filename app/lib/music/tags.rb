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
    TRACK = %w[track tracknumber].freeze
    DISC = %w[disc discnumber].freeze

    def initialize(ffprobe: ::Ffprobe.new)
      @ffprobe = ffprobe
    end

    def read(path)
      described = ffprobe.describe(path)
      format = described.fetch("format", {})
      tags = normalize(format["tags"])
      artist = value(tags, ARTIST)

      FileTags.new(
        title: value(tags, TITLE) || ::File.basename(path.to_s, ".*"),
        artist: artist,
        album_artist: value(tags, ALBUM_ARTIST) || artist,
        album: value(tags, ALBUM),
        year: year(tags),
        track_no: number(tags, TRACK),
        disc_no: number(tags, DISC) || 1,
        duration: format["duration"]&.to_f,
        audio: audio_of(described, format, path)
      )
    end

    private

    attr_reader :ffprobe

    # The physical encoding, read off the first audio stream. A file with no
    # audio stream — a stray image, a corrupt download — simply has none.
    #
    # Only a compressed file is asked how it spends its bits, and it is asked
    # last: the answer costs a second walk through the file, and a lossless one
    # would have nothing to say for it.
    def audio_of(described, format, path)
      stream = (described["streams"] || []).find { |each| each["codec_type"] == "audio" }
      return unless stream

      audio = Audio.new(
        codec: stream["codec_name"],
        bit_depth: bit_depth(stream),
        sample_rate: stream["sample_rate"]&.to_i,
        bit_rate: (stream["bit_rate"] || format["bit_rate"])&.to_i
      )
      return audio unless audio.lossy?

      audio.with(bit_rate_mode: BitRateMode.of(ffprobe.frame_sizes(path)))
    end

    # Lossless codecs report a real depth; lossy ones report 0, which means "not
    # a thing I have".
    def bit_depth(stream)
      depth = (stream["bits_per_raw_sample"] || stream["bits_per_sample"]).to_i

      depth if depth.positive?
    end

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
