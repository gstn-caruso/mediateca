module Video
  # Turns ffprobe's description of a file into the vocabulary Video::Playback
  # speaks. It never runs a process: Video::Ffprobe does that, and can be
  # replaced by anything that answers #streams.
  class Probe
    def initialize(ffprobe: ::Ffprobe.new)
      @ffprobe = ffprobe
    end

    def examine(path)
      streams = ffprobe.describe(path).fetch("streams", [])
      raise Unreadable, "#{path} has no streams" if streams.empty?

      Media.new(
        container: container_of(path),
        video: video_stream(streams),
        audios: audio_streams(streams)
      )
    end

    private

    attr_reader :ffprobe

    # The browser cares about the container, and the extension is what the
    # scanner and the filesystem agree on. ffprobe's format_name is no help:
    # it reports "matroska,webm" for both, and mkv plays nowhere while webm
    # plays everywhere.
    def container_of(path)
      ::File.extname(path.to_s).downcase.delete_prefix(".")
    end

    # Cover art rides along as a video stream. It is a picture, not a movie.
    def video_stream(streams)
      found = streams.find { |stream| stream["codec_type"] == "video" && !attached_picture?(stream) }

      found && to_stream(found, index: 0)
    end

    # ffmpeg's -map counts audio streams among themselves (0:a:0, 0:a:1), not
    # by their position in the file, so that is how we number them.
    def audio_streams(streams)
      streams.select { |stream| stream["codec_type"] == "audio" }
             .each_with_index
             .map { |stream, position| to_stream(stream, index: position) }
    end

    def to_stream(stream, index:)
      tags = stream["tags"] || {}

      Stream.new(
        index: index,
        codec: stream["codec_name"],
        channels: stream["channels"],
        language: tags["language"],
        title: tags["title"]
      )
    end

    def attached_picture?(stream)
      stream.dig("disposition", "attached_pic").to_i == 1
    end
  end
end
