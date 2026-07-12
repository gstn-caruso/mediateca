module Music
  # How a file is encoded, as opposed to what it was tagged: the codec, and the
  # numbers that measure its fidelity. Lossless files are told apart by depth
  # and sample rate ("16 / 44.1"); lossy ones by their bitrate ("320").
  #
  # `sample_rate` and `bit_rate` are in hertz and bits per second; `bit_depth`
  # is bits, and is nil for a codec that has no fixed one.
  #
  # The catalog keeps the four numbers in four columns, but they only mean
  # something together, so it is here — not in the view that shows them — that
  # they are read.
  class Audio < Data.define(:codec, :bit_depth, :sample_rate, :bit_rate)
    # Codecs that keep every sample: their fidelity is the depth and rate they
    # were captured at, not a bitrate a compressor settled on. The whole library
    # is FLAC, but the badge reads the same way for anything lossless.
    LOSSLESS = %w[flac alac wav wavpack ape].freeze

    # A file scanned before we recorded encodings has nothing to say about
    # itself.
    def known?
      codec.present?
    end

    def lossless?
      known? && LOSSLESS.include?(codec.downcase)
    end

    # A short badge: "FLAC · 16/44.1" for a lossless file, "MP3 · 320" for a
    # compressed one. Nil when nothing was recorded, so the badge just doesn't
    # show.
    def quality
      return unless known?

      [ codec.upcase, fidelity ].compact.join(" · ")
    end

    # The long form, for a tooltip: every measure we have, spelled out.
    def detail
      return unless known?

      [
        codec.upcase,
        ("#{bit_depth}-bit" if bit_depth),
        ("#{khz(sample_rate)} kHz" if sample_rate),
        ("#{kbps(bit_rate)} kbps" if bit_rate)
      ].compact.join(" · ")
    end

    private

    # A lossless file's fidelity is its depth and rate; a lossy one's is the
    # bitrate it chose.
    def fidelity
      if lossless?
        "#{bit_depth}/#{khz(sample_rate)}" if bit_depth && sample_rate
      elsif bit_rate
        kbps(bit_rate)
      end
    end

    # 44100 → "44.1", 48000 → "48", 96000 → "96".
    def khz(hertz)
      format("%g", hertz / 1000.0)
    end

    def kbps(bits_per_second)
      (bits_per_second / 1000.0).round
    end
  end
end
