require "test_helper"

module Video
  # Probe doesn't run processes: it interprets what ffprobe says. These tests
  # feed it real ffprobe output, recorded under test/fixtures/ffprobe, and
  # don't need ffmpeg installed. Whether ffprobe still talks this way is
  # verified by test/contracts/ffmpeg_contract_test.rb.
  class ProbeTest < ActiveSupport::TestCase
    include VideoBuilders

    test "reads the container and the video track" do
      found = recorded_probe.examine("direct.mp4")

      assert_equal "mp4", found.container
      assert_equal "h264", found.video.codec
    end

    # The container comes from the extension, not from ffprobe: format_name
    # says "matroska,webm" for both, and nobody opens mkv while webm works fine.
    test "the container comes from the extension" do
      assert_equal "avi", recorded_probe.examine("/wherever/old.avi").container
    end

    test "reads each audio track with its language and title" do
      found = recorded_probe.examine("two-tracks.mkv")

      assert_equal %w[aac flac], found.audios.map(&:codec)
      assert_equal %w[spa eng], found.audios.map(&:language)
      assert_equal [ "Español", "English" ], found.audios.map(&:title)
    end

    # The indexes are ffmpeg's within the audio group (0:a:0, 0:a:1), not the
    # file's: it's what -map needs.
    test "audio tracks are numbered from zero" do
      assert_equal [ 0, 1 ], recorded_probe.examine("two-tracks.mkv").audios.map(&:index)
    end

    test "reads the channels of each track" do
      assert_equal [ 1, 1 ], recorded_probe.examine("two-tracks.mkv").audios.map(&:channels)
    end

    test "a file with no audio has no audio tracks" do
      assert_empty recorded_probe.examine("silent.mkv").audios
    end

    test "recognizes an old container and codec" do
      found = recorded_probe.examine("old.avi")

      assert_equal "mpeg4", found.video.codec
      assert_equal "mp3", found.audios.sole.codec
    end

    # An embedded cover travels as a video track. It's a photo, not a movie,
    # and mistaking it for the file's video would ruin the decision.
    test "an embedded cover isn't mistaken for the video" do
      probe = probe_reporting([
        { "codec_type" => "video", "codec_name" => "mjpeg", "disposition" => { "attached_pic" => 1 } },
        { "codec_type" => "video", "codec_name" => "h264", "disposition" => { "attached_pic" => 0 } }
      ])

      assert_equal "h264", probe.examine("movie.mkv").video.codec
    end

    test "a file with no tracks is unreadable" do
      assert_raises(Unreadable) { probe_reporting([]).examine("empty.mkv") }
    end

    test "a file with no video tracks reads all the same: it can be audio-only" do
      probe = probe_reporting([ { "codec_type" => "audio", "codec_name" => "aac", "channels" => 2 } ])

      assert_nil probe.examine("audio-only.mkv").video
    end

    # What comes out of the probe is exactly what Playback needs to read.
    test "what comes out of the probe feeds the playback decision" do
      assert Playback.for(recorded_probe.examine("direct.mp4")).direct?
      refute Playback.for(recorded_probe.examine("two-tracks.mkv")).direct?
    end
  end
end
