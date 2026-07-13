require "test_helper"

class FfmpegTest < ActiveSupport::TestCase
  include Sleeves

  test "an image comes back as its pixels, and nothing else" do
    pixels = Ffmpeg.new.pixels(sleeve("#c8102e" => 1.0), size: 8)

    assert_equal 64, pixels.size # 8 by 8
    assert_equal [ 200, 16, 46 ], pixels.first
  end

  # The NAS is full of files somebody's ripper wrote in 2006. A cover.jpg that is
  # not a JPEG is refused, and refused as the file's problem, not as a crash.
  test "a file that is not an image is refused" do
    not_an_image = Rails.root.join("tmp/not-an-image-#{Process.pid}.jpg").tap { |path| path.write("hello") }

    assert_raises(Ffmpeg::Unreadable) { Ffmpeg.new.pixels(not_an_image, size: 8) }
  end

  # And a missing ffmpeg is our problem, said out loud rather than swallowed into
  # a library with no colours in it.
  test "a missing ffmpeg says so" do
    with_ffmpeg_at("/nowhere/ffmpeg") do
      assert_raises(Ffmpeg::NotInstalled) { Ffmpeg.new.pixels(sleeve("#c8102e" => 1.0), size: 8) }
    end
  end

  private

  def with_ffmpeg_at(binary)
    was = Rails.configuration.x.ffmpeg
    Rails.configuration.x.ffmpeg = binary
    yield
  ensure
    Rails.configuration.x.ffmpeg = was
  end
end
