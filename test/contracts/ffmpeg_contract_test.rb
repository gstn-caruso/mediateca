require "test_helper"
require "open3"
require "tmpdir"

# The only tests that run real ffmpeg.
#
# The rest of the suite works against recorded ffprobe output and against
# commands that nobody runs, so it doesn't need ffmpeg installed. What nothing
# else can verify is exactly what these tests verify: that ffprobe still
# describes the files the way we recorded them, and that ffmpeg understands
# the arguments we build.
#
# They're skipped if ffmpeg isn't there. It's there in CI, so they're never
# skipped there.
class FfmpegContractTest < ActiveSupport::TestCase
  include VideoBuilders

  RECORDED = %w[direct.mp4 two-tracks.mkv silent.mkv old.avi].freeze

  setup do
    next if ffmpeg_installed?

    # Silently skipping where these are supposed to run would be worse than
    # not having them at all: the suite would go green without verifying anything.
    flunk "ffmpeg is not installed and REQUIRE_FFMPEG demands it" if ENV["REQUIRE_FFMPEG"].present?

    skip "ffmpeg is not installed"
  end

  test "the recorded ffprobe output still matches the real thing" do
    RECORDED.each do |name|
      real = Video::Probe.new.examine(fixture(name))
      recorded = recorded_probe.examine(name)

      assert_equal recorded, real,
        "the recording at test/fixtures/ffprobe/#{name.sub(/\.\w+$/, '.json')} is stale"
    end
  end

  test "ffprobe rejects something that isn't a video" do
    assert_raises(Video::Unreadable) { Ffprobe.new.describe(__FILE__) }
  end

  test "ffmpeg converts an old avi into something the browser understands" do
    found = Video::Probe.new.examine(convert("old.avi"))

    assert_equal "mp4", found.container
    assert_equal "h264", found.video.codec
  end

  test "ffmpeg remuxes the video without recompressing it" do
    assert_equal "h264", Video::Probe.new.examine(convert("two-tracks.mkv")).video.codec
  end

  test "ffmpeg delivers the audio track that was requested" do
    # Track 1 is FLAC, which the browser doesn't understand: it comes out recoded to aac.
    assert_equal "aac", Video::Probe.new.examine(convert("two-tracks.mkv", audio: 1)).audios.sole.codec
  end

  test "neither chapters nor data tracks make it into the output" do
    streams = Ffprobe.new.describe(convert("two-tracks.mkv")).fetch("streams")

    assert_empty streams.select { |stream| stream["codec_type"] == "data" }
  end

  test "delivers the bytes in chunks, without buffering the whole file in memory" do
    chunks = 0
    Video::Conversion.new.stream(fixture("old.avi"), playback_for("old.avi")) { chunks += 1 }

    assert_operator chunks, :>, 0
  end

  test "a file ffmpeg can't read raises an error" do
    assert_raises(Video::Conversion::Failed) do
      Video::Conversion.new.stream(__FILE__, playback_for("old.avi")) { |chunk| chunk }
    end
  end

  private

  def ffmpeg_installed?
    [ Rails.configuration.x.ffmpeg, Rails.configuration.x.ffprobe ].all? do |binary|
      Open3.capture3(binary, "-version")
      true
    rescue Errno::ENOENT
      false
    end
  end

  def fixture(name)
    Rails.root.join("test/fixtures/videos", name).to_s
  end

  def playback_for(name, audio: 0)
    Video::Playback.for(Video::Probe.new.examine(fixture(name)), audio:)
  end

  def convert(name, audio: 0)
    output = File.join(Dir.mktmpdir("conversion"), "salida.mp4")

    File.open(output, "wb") do |file|
      Video::Conversion.new.stream(fixture(name), playback_for(name, audio:)) { |chunk| file.write(chunk) }
    end

    output
  end
end
