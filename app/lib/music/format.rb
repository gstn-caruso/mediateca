module Music
  # The audio the library holds, named by the container it comes in.
  #
  # Two questions, one list. The scan asks which files under an album folder are
  # tracks at all; the stream asks what to call one when it hands it to the
  # browser. They have to agree: a file we would not know how to announce is a
  # file the browser could not play, so it is not one worth counting.
  #
  # FLAC is what almost every album is. The rest is what an album is when FLAC
  # was never an option — a record no tracker ever carried, and the only copy
  # there is came off YouTube. Rack's own table knows none of these three by the
  # names that matter here, so the library keeps its own.
  class Format
    CONTENT_TYPES = {
      ".flac" => "audio/flac",
      ".opus" => "audio/ogg",
      ".mp3" => "audio/mpeg"
    }.freeze

    class << self
      def audio?(path)
        CONTENT_TYPES.key?(extension(path))
      end

      def content_type(path)
        CONTENT_TYPES[extension(path)]
      end

      private

      def extension(path)
        ::File.extname(path.to_s).downcase
      end
    end
  end
end
