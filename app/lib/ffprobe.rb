require "json"
require "open3"

# The only object that knows ffprobe is a process. It answers with ffprobe's
# raw description of a file; making sense of it belongs to whoever asked —
# Music::Tags reads the format's tags and the audio stream behind them.
class Ffprobe
  # ffmpeg is missing. Not the file's fault; ours.
  NotInstalled = Class.new(StandardError)

  # The file is not something we can read — or not something at all.
  Unreadable = Class.new(StandardError)

  DESCRIPTION = %w[-v error -print_format json -show_streams -show_format].freeze

  # Every compressed frame, and nothing about it but how many bytes it took.
  FRAME_SIZES = %w[-v error -print_format json -select_streams a:0 -show_entries packet=size].freeze

  def describe(path)
    ask(DESCRIPTION, path)
  end

  # The size of each of the file's frames, in bytes, in the order it plays them.
  #
  # This walks the whole file where `describe` only reads its head, so ask it of
  # a file that has an answer worth the walk — see Music::BitRateMode. It is
  # cheaper than it sounds: ffprobe reads frame headers here, and decodes
  # nothing.
  def frame_sizes(path)
    ask(FRAME_SIZES, path).fetch("packets", []).filter_map { |frame| frame["size"]&.to_i }
  end

  private

  # Every question is the same call, and only the arguments differ: run ffprobe
  # over the file, refuse what it could not read, and hand back the JSON it
  # answered with.
  def ask(arguments, path)
    output, complaints, status = Open3.capture3(binary, *arguments, path.to_s)
    raise Unreadable, "ffprobe could not read #{path}: #{complaints.strip}" unless status.success?

    JSON.parse(output)
  rescue Errno::ENOENT
    raise NotInstalled, "can't find #{binary.inspect}: install ffmpeg or point FFPROBE at the binary"
  rescue JSON::ParserError => e
    raise Unreadable, "ffprobe returned something that isn't JSON for #{path}: #{e.message}"
  end

  def binary
    Rails.configuration.x.ffprobe
  end
end
