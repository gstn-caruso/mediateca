require "test_helper"

class Music::ThumbnailTest < ActiveSupport::TestCase
  include Sleeves
  include Pictures

  # A sleeve as it actually arrives: a big square scan, far more picture than any
  # row in the app is ever going to draw.
  SCAN = 600

  setup { @cover = sleeve({ "#c8102e" => 1.0 }, SCAN) }

  test "a picture is drawn at the size it will be drawn at" do
    assert_equal [ 96, 96 ], measure(Music::Thumbnail.of(@cover, size: 96))
  end

  # The whole point: a row that draws a sleeve at forty-four pixels is handed
  # forty-four pixels, and not the scan.
  test "the thumbnail is a fraction of the picture it came off" do
    thumbnail = Music::Thumbnail.of(@cover, size: 96)

    assert_operator File.size(thumbnail), :<, File.size(@cover) / 4
  end

  # Drawing one costs an ffmpeg. Drawing it again, for every request, for every
  # row, on every page, would cost the NAS more than sending the whole sleeve
  # ever did.
  test "a picture is drawn once and handed over from then on" do
    first = Music::Thumbnail.of(@cover, size: 96)
    drawn_at = File.mtime(first)

    assert_equal first, Music::Thumbnail.of(@cover, size: 96)
    assert_equal drawn_at, File.mtime(first), "the thumbnail was drawn a second time"
  end

  # A better scan of a record, dropped onto the NAS over the old one, is a new
  # picture at the same path. The thumbnail on disk is now a picture of something
  # that is not there any more.
  test "a picture that changed on disk is drawn again" do
    was = File.size(Music::Thumbnail.of(@cover, size: 96))

    File.binwrite(@cover, File.binread(sleeve({ "#101010" => 0.5, "#f5f5f5" => 0.5 }, SCAN)))
    FileUtils.touch(@cover, mtime: Time.now + 1)

    assert_not_equal was, File.size(Music::Thumbnail.of(@cover, size: 96)),
      "the app is still drawing the sleeve that used to be at that path"
  end

  # A URL that can ask for any size is a URL that can ask the NAS to draw ten
  # thousand of them.
  test "nobody can ask for a size the app does not draw" do
    assert_nil Music::Thumbnail.of(@cover, size: 5000)
    assert_nil Music::Thumbnail.of(@cover, size: nil)
  end

  # Three of the seventy-five sleeves on the NAS are a cover.jpg somebody's ripper
  # wrote in 2006, and one of them is not a JPEG at all. A page still wants a
  # picture there: it gets the file, exactly as it did before.
  test "a picture ffmpeg cannot read has no thumbnail, and does not blow up" do
    not_a_picture = Rails.root.join("tmp/not-a-picture-#{Process.pid}.jpg").tap { it.write("hello") }

    assert_nil Music::Thumbnail.of(not_a_picture, size: 96)
  end

  # Blowing a small picture up would cost bytes to add nothing: the browser can
  # stretch it for free, and stretching is all we would be doing.
  test "a picture already smaller than the size asked for is left the size it is" do
    small = sleeve({ "#c8102e" => 1.0 }, 48)

    assert_equal [ 48, 48 ], measure(Music::Thumbnail.of(small, size: 640))
  end
end
