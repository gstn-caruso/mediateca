require "json"
require "open3"

# The only object that knows ffprobe is a process. It answers with ffprobe's
# raw description of a file; making sense of it belongs to whoever asked —
# Video::Probe reads the streams, Music::Tags reads the format's tags.
class Ffprobe
  # ffmpeg is missing. Not the file's fault; ours.
  NotInstalled = Class.new(StandardError)

  # The file is not something we can read — or not something at all.
  Unreadable = Class.new(StandardError)

  ARGUMENTS = %w[-v error -print_format json -show_streams -show_format].freeze

  def describe(path)
    output, complaints, status = Open3.capture3(binary, *ARGUMENTS, path.to_s)
    raise Unreadable, "ffprobe no pudo leer #{path}: #{complaints.strip}" unless status.success?

    JSON.parse(output)
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
