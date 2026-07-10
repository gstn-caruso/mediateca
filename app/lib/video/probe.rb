require "json"
require "open3"

module Video
  # Asks ffprobe what is inside a media file, and answers in the vocabulary
  # Video::Playback speaks.
  class Probe
    Unreadable = Class.new(StandardError)

    ARGUMENTS = %w[-v error -print_format json -show_streams].freeze

    def examine(path)
      streams = read(path)

      Media.new(
        container: container_of(path),
        video: video_stream(streams),
        audios: audio_streams(streams)
      )
    end

    private

    def read(path)
      output, error, status = Open3.capture3(ffprobe, *ARGUMENTS, path.to_s)
      raise Unreadable, "ffprobe no pudo leer #{path}: #{error.strip}" unless status.success?

      streams = JSON.parse(output).fetch("streams", [])
      raise Unreadable, "#{path} no tiene ninguna pista" if streams.empty?

      streams
    rescue JSON::ParserError => e
      raise Unreadable, "ffprobe devolvió algo que no es JSON para #{path}: #{e.message}"
    end

    # The browser cares about the container, and the extension is what beets,
    # the scanner and the filesystem all agree on. ffprobe's format_name is no
    # help here: it reports "matroska,webm" for both, and mkv plays nowhere
    # while webm plays everywhere.
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

    def ffprobe
      Rails.configuration.x.ffprobe
    end
  end
end
