module Music
  # How a file is encoded, as opposed to what it was tagged: the codec, and the
  # numbers that measure its fidelity.
  #
  # The badge says as little as it can get away with. A lossless file kept every
  # sample, so its format is the whole claim — FLAC is FLAC, at 16/44.1 or at
  # 24/192. A compressed one threw samples away, so it owes two answers: how many
  # bits it was given, and whether it held that number or let it follow the music
  # (see BitRateMode). Everything measured is still in `detail`, for the tooltip.
  #
  # `sample_rate` and `bit_rate` are in hertz and bits per second; `bit_depth` is
  # bits, and is nil for a codec that has no fixed one.
  #
  # The catalog keeps the measures in columns of their own, but they only mean
  # something together, so it is here — not in the view that shows them — that
  # they are read.
  class Audio < Data.define(:codec, :bit_depth, :sample_rate, :bit_rate, :bit_rate_mode)
    # Codecs that keep every sample: their fidelity is the depth and rate they
    # were captured at, not a bitrate a compressor settled on.
    LOSSLESS = %w[flac alac wav wavpack ape].freeze

    # No scan measures everything. A lossless file is never asked how it spends
    # its bits, a lossy one has no fixed depth, and a file read before we
    # recorded encodings has none of it.
    def initialize(codec: nil, bit_depth: nil, sample_rate: nil, bit_rate: nil, bit_rate_mode: nil)
      super
    end

    # A file scanned before we recorded encodings has nothing to say about
    # itself.
    def known?
      codec.present?
    end

    def lossless?
      known? && LOSSLESS.include?(codec.downcase)
    end

    # Not the opposite of lossless: a file we cannot name a codec for is neither.
    def lossy?
      known? && !lossless?
    end

    # A short badge: "FLAC" for a lossless file, "MP3 · 320" for a compressed
    # one. Nil when nothing was recorded, so the badge just doesn't show.
    def quality
      return unless known?

      [ codec.upcase, (kbps(bit_rate) if lossy? && bit_rate) ].compact.join(" · ")
    end

    # The long form, for a tooltip: every measure we have, spelled out —
    # including the depth and rate the badge no longer carries, and the word for
    # the mode the badge shows as an icon.
    def detail
      return unless known?

      [
        codec.upcase,
        ("#{bit_depth}-bit" if bit_depth),
        ("#{khz(sample_rate)} kHz" if sample_rate),
        ("#{kbps(bit_rate)} kbps" if bit_rate),
        ("#{bit_rate_mode} bitrate" if bit_rate_mode)
      ].compact.join(" · ")
    end

    private

    # 44100 → "44.1", 48000 → "48", 96000 → "96".
    def khz(hertz)
      format("%g", hertz / 1000.0)
    end

    def kbps(bits_per_second)
      (bits_per_second / 1000.0).round
    end
  end
end
