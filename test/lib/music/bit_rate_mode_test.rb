require "test_helper"

module Music
  # The sizes are real: they come from ffprobe reading LAME and ffmpeg encodes
  # of the same two minutes of audio.
  class BitRateModeTest < ActiveSupport::TestCase
    test "frames that are all one size were given a bitrate and held to it" do
      assert_equal "constant", BitRateMode.of([ 576, 576, 576, 576 ])
    end

    # MP3's frame is 144 * bitrate / sample rate bytes, which almost never
    # divides evenly — so a file holding 320 kbps at 44.1 kHz still alternates
    # between 1044 and 1045 bytes. That byte is the padding bit, not a decision.
    test "a byte of wobble is the padding bit, and still a held bitrate" do
      assert_equal "constant", BitRateMode.of([ 1044, 1045, 1045, 1044 ])
      assert_equal "constant", BitRateMode.of([ 417, 418, 418, 417 ])
    end

    test "frames that swing wider than the padding followed the music" do
      assert_equal "variable", BitRateMode.of([ 417, 419 ])
      assert_equal "variable", BitRateMode.of([ 208, 417, 365, 626 ])
    end

    # A file whose frames we never counted — a lossless one is never asked, and
    # a file scanned before we started asking has nothing to say.
    test "frames nobody counted say nothing either way" do
      assert_nil BitRateMode.of([])
      assert_nil BitRateMode.of(nil)
    end

    # Degenerate, but a file of one frame did not vary anything.
    test "a single frame varied nothing" do
      assert_equal "constant", BitRateMode.of([ 835 ])
    end
  end
end
