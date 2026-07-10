require "json"
require "open3"

module Video
  # The only object that knows ffprobe is a process. It answers with the raw
  # stream descriptions; making sense of them is Video::Probe's job.
  class Ffprobe
    ARGUMENTS = %w[-v error -print_format json -show_streams].freeze

    def streams(path)
      output, complaints, status = Open3.capture3(binary, *ARGUMENTS, path.to_s)
      raise Unreadable, "ffprobe no pudo leer #{path}: #{complaints.strip}" unless status.success?

      JSON.parse(output).fetch("streams", [])
    rescue Errno::ENOENT
      raise NotInstalled, "no encuentro #{binary.inspect}: instalá ffmpeg o apuntá FFPROBE al binario"
    rescue JSON::ParserError => e
      raise Unreadable, "ffprobe devolvió algo que no es JSON para #{path}: #{e.message}"
    end

    private

    def binary
      Rails.configuration.x.ffprobe
    end
  end
end
