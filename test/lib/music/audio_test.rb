require "test_helper"

module Music
  class AudioTest < ActiveSupport::TestCase
    # A lossless file is measured by its depth and sample rate: the badge every
    # FLAC in the library wears.
    test "a lossless file's badge is its codec, depth and sample rate" do
      assert_equal "FLAC · 16/44.1", audio(codec: "flac", bit_depth: 16, sample_rate: 44100).quality
      assert_equal "FLAC · 24/96", audio(codec: "flac", bit_depth: 24, sample_rate: 96000).quality
      assert_equal "FLAC · 24/88.2", audio(codec: "flac", bit_depth: 24, sample_rate: 88200).quality
    end

    # A compressed file has no fixed depth, so its badge is the bitrate it
    # settled on, in kilobits.
    test "a lossy file's badge is its codec and bitrate" do
      assert_equal "MP3 · 320", audio(codec: "mp3", bit_rate: 320000).quality
      assert_equal "AAC · 256", audio(codec: "aac", bit_rate: 256000).quality
    end

    # Half a measure is no measure: without both numbers there is no "16/44.1"
    # to show, and the codec alone is all the badge can honestly say.
    test "a lossless file missing a number is named by its codec alone" do
      assert_equal "FLAC", audio(codec: "flac", sample_rate: 44100).quality
      assert_equal "FLAC", audio(codec: "flac", bit_depth: 16).quality
    end

    test "a lossy file with no bitrate is named by its codec alone" do
      assert_equal "MP3", audio(codec: "mp3").quality
    end

    # Scanned before we recorded encodings: no badge rather than a blank one.
    test "a file with no known codec has no badge" do
      assert_not audio(codec: nil).known?
      assert_nil audio(codec: nil).quality
      assert_nil audio(codec: nil).detail
    end

    test "a codec that keeps every sample is lossless" do
      assert audio(codec: "flac").lossless?
      assert_not audio(codec: "mp3").lossless?
      assert_not audio(codec: nil).lossless?
    end

    # The tooltip spells out everything measured, bitrate and all.
    test "the detailed quality names every measure it has" do
      assert_equal "FLAC · 16-bit · 44.1 kHz · 1007 kbps",
        audio(codec: "flac", bit_depth: 16, sample_rate: 44100, bit_rate: 1006840).detail
    end

    test "the detailed quality leaves out what was never measured" do
      assert_equal "MP3 · 320 kbps", audio(codec: "mp3", bit_rate: 320000).detail
    end

    private

    def audio(codec: nil, bit_depth: nil, sample_rate: nil, bit_rate: nil)
      Audio.new(codec:, bit_depth:, sample_rate:, bit_rate:)
    end
  end
end
