require "json"

# Builds the description of a media file the way Video::Probe reports it, so the
# playback rules can be tested without ever opening a video.
module VideoBuilders
  # Answers with ffprobe output captured from the real binary and frozen under
  # test/fixtures/ffprobe. The parsing is exercised against what ffprobe
  # actually says, and no test needs ffmpeg installed to run.
  class RecordedFfprobe
    def describe(path)
      recording = Rails.root.join("test/fixtures/ffprobe", "#{File.basename(path, '.*')}.json")
      raise Ffprobe::Unreadable, "no recorded ffprobe output for #{path}" unless recording.exist?

      JSON.parse(recording.read)
    end
  end

  # For the shapes we have no recording of.
  class FakeFfprobe
    def initialize(streams: [], format: {})
      @description = { "streams" => streams, "format" => format }
    end

    def describe(_path)
      @description
    end
  end

  def recorded_probe
    Video::Probe.new(ffprobe: RecordedFfprobe.new)
  end

  def probe_reporting(streams)
    Video::Probe.new(ffprobe: FakeFfprobe.new(streams:))
  end

  def media(container: "mkv", video: "h264", audios: [ "aac" ], channels: 2)
    Video::Media.new(
      container:,
      video: video && Video::Stream.new(index: 0, codec: video, channels: nil, language: nil, title: nil),
      audios: audios.each_with_index.map do |codec, position|
        Video::Stream.new(index: position + 1, codec:, channels:, language: nil, title: nil)
      end
    )
  end
end
