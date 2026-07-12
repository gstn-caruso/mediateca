module Music
  # What a compressed file did with its bitrate: held the one it was given, or
  # let it follow the music.
  #
  # No encoder writes this down anywhere ffprobe can read it — a file that held
  # 320 kbps and one that averaged its way there describe themselves in exactly
  # the same words. So the file is asked the only way it can answer: by the size
  # of its frames. An encoder holding a bitrate emits frames of one size; one
  # following the music emits whatever each moment costs, and the quiet moments
  # cost less.
  module BitRateMode
    CONSTANT = "constant".freeze
    VARIABLE = "variable".freeze

    # MP3 sizes a frame at 144 * bitrate / sample rate bytes, which almost never
    # divides evenly, so it pads the short ones with a byte. A file wobbling by
    # that byte and no more is holding its bitrate, not varying it.
    PADDING = 1

    # Nil when there are no frames to read: a lossless file is never asked, and
    # one scanned before we started asking has nothing to say.
    def self.of(frame_sizes)
      return if frame_sizes.blank?

      frame_sizes.max - frame_sizes.min <= PADDING ? CONSTANT : VARIABLE
    end
  end
end
