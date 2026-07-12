require "test_helper"

module Music
  class AudioTest < ActiveSupport::TestCase
    # A lossless file kept every sample it was given, so its name is the whole
    # claim: a FLAC is a FLAC whether it was captured at 16/44.1 or 24/192. The
    # numbers are still in the tooltip for whoever wants them.
    test "a lossless file's badge is its format, and nothing else" do
      assert_equal "FLAC", audio(codec: "flac", bit_depth: 16, sample_rate: 44100).quality
      assert_equal "FLAC", audio(codec: "flac", bit_depth: 24, sample_rate: 192000).quality
      assert_equal "ALAC", audio(codec: "alac", bit_depth: 24, sample_rate: 96000).quality
    end

    # A compressed file threw samples away, and how many is the only thing worth
    # asking: it is only as good as the bits it was given.
    test "a lossy file's badge is its format and the bits it was given" do
      assert_equal "MP3 · 320", audio(codec: "mp3", bit_rate: 320000).quality
      assert_equal "AAC · 256", audio(codec: "aac", bit_rate: 256000).quality
      assert_equal "OPUS · 128", audio(codec: "opus", bit_rate: 128000).quality
    end

    test "a lossy file with no bitrate is named by its format alone" do
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
      assert_not audio(codec: "flac").lossy?
      assert audio(codec: "mp3").lossy?
      assert_not audio(codec: "mp3").lossless?
    end

    # Neither, until we know which: nothing is lossy just for being unreadable.
    test "a file with no known codec is neither lossless nor lossy" do
      assert_not audio(codec: nil).lossless?
      assert_not audio(codec: nil).lossy?
    end

    # The badge shows the mode as an icon, so the words belong in the tooltip.
    test "the detailed quality names every measure it has" do
      assert_equal "FLAC · 24-bit · 192 kHz · 4608 kbps",
        audio(codec: "flac", bit_depth: 24, sample_rate: 192000, bit_rate: 4608000).detail
      assert_equal "MP3 · 320 kbps · variable bitrate",
        audio(codec: "mp3", bit_rate: 320000, bit_rate_mode: "variable").detail
    end

    test "the detailed quality leaves out what was never measured" do
      assert_equal "MP3 · 320 kbps", audio(codec: "mp3", bit_rate: 320000).detail
    end

    private

    def audio(codec: nil, bit_depth: nil, sample_rate: nil, bit_rate: nil, bit_rate_mode: nil)
      Audio.new(codec:, bit_depth:, sample_rate:, bit_rate:, bit_rate_mode:)
    end
  end
end
