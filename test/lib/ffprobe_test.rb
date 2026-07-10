require "test_helper"

class FfprobeTest < ActiveSupport::TestCase
  # Without ffprobe, Open3 raises Errno::ENOENT and the message doesn't say what to install.
  # This test doesn't need ffmpeg: it needs precisely its absence.
  test "if ffprobe isn't installed, the error says so" do
    original = Rails.configuration.x.ffprobe
    Rails.configuration.x.ffprobe = "ffprobe-that-does-not-exist"

    error = assert_raises(Ffprobe::NotInstalled) { Ffprobe.new.describe("whatever.mkv") }
    assert_match(/ffprobe-that-does-not-exist/, error.message)
    assert_match(/install ffmpeg/, error.message)
  ensure
    Rails.configuration.x.ffprobe = original
  end
end
