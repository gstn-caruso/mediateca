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

  # And a sleeve does not arrive on this NAS by being edited in place. It arrives
  # by rsync -a, or cp -p, which carry the file's own mtime with it — and the file
  # was made long before the thumbnail was drawn. A thumbnail that only redraws for
  # a picture NEWER than itself never redraws for the way pictures actually land
  # here, and the listener is shown the old sleeve for ever.
  test "a picture that landed carrying an older mtime is drawn again" do
    was = File.size(Music::Thumbnail.of(@cover, size: 96))

    File.binwrite(@cover, File.binread(sleeve({ "#101010" => 0.5, "#f5f5f5" => 0.5 }, SCAN)))
    FileUtils.touch(@cover, mtime: Time.now - 1.year)

    assert_not_equal was, File.size(Music::Thumbnail.of(@cover, size: 96)),
      "rsync kept the sleeve's own mtime, and the app decided the new sleeve was the old one"
  end

  # A URL cannot ask for a size, but a URL can ask for anything: `?size[]=96`
  # arrives as an Array, and an Array does not answer to to_i.
  test "a size that is not even a number is simply not a size" do
    assert_nil Music::Thumbnail.of(@cover, size: [ "96" ])
    assert_nil Music::Thumbnail.of(@cover, size: "ninety-six")
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

  # A record gets re-ripped, or moved, or thrown away, and the catalog still has
  # the path it used to be at. There is a thumbnail of it sitting on disk, drawn
  # back when the file was there — and asking a picture that does not exist when it
  # was last changed is asking a question about nothing.
  test "a picture that is no longer on disk has no thumbnail" do
    Music::Thumbnail.of(@cover, size: 96)
    File.delete(@cover)

    assert_nil Music::Thumbnail.of(@cover, size: 96)
  end

  # One of the four sizes is not a picture at all. The wash behind a title is the
  # sleeve blown up seventeen times, and blowing a picture up is not blurring it:
  # what came back was the sleeve in blocks, with the lettering still legible and
  # the eight-by-eight grid of the JPEG spread out into squares a hand's width
  # across. It was pixelated, and the stylesheet had been claiming for a while
  # that it could not be.
  #
  # So the edges are taken out before it is ever sent, where a blur costs one
  # ffmpeg once and not a frame on somebody's phone. What is drawn at 64 is a
  # light, and a light has no edges in it — which is a thing a test can measure.
  test "the light behind a title has no edge left in it" do
    bands = sleeve({ "#101010" => 0.5, "#f5f5f5" => 0.5 }, SCAN)

    assert_operator steepest_edge(Music::Thumbnail.of(bands, size: 64)), :<, 200,
      "the wash still has the sleeve's edges in it, and a browser stretching those is what pixelated looks like"
    assert_operator steepest_edge(Music::Thumbnail.of(bands, size: 96)), :>, 500,
      "a picture is a picture: only the light is softened, and this one lost its edge too"
  end

  # And the light has to say so in its name.
  #
  # A thumbnail is redrawn when the picture it came off changes, and a sleeve
  # sitting on a NAS does not change. Every 64 already on that disk was drawn
  # sharp by the build before this one — so a light that answered to the same name
  # would never be drawn at all, and every record anybody has ever opened would
  # keep its pixelated wash for ever, on a fix that passed all its tests.
  test "a sharp one left behind by an older build is not handed out as the light" do
    bands = sleeve({ "#101010" => 0.5, "#f5f5f5" => 0.5 }, SCAN)
    drawn_by_the_last_build(bands)

    assert_operator steepest_edge(Music::Thumbnail.of(bands, size: 64)), :<, 200,
      "the sharp 64 the last build drew is being handed out as the light, and nothing will ever redraw it"
  end

  # Blowing a small picture up would cost bytes to add nothing: the browser can
  # stretch it for free, and stretching is all we would be doing.
  test "a picture already smaller than the size asked for is left the size it is" do
    small = sleeve({ "#c8102e" => 1.0 }, 48)

    assert_equal [ 48, 48 ], measure(Music::Thumbnail.of(small, size: 640))
  end

  private

  # The 64 as the build before this one drew it: sharp, sitting in the thumbnail
  # directory under the name that build gave it, and wearing the sleeve's own
  # mtime — which is what tells this app a thumbnail is still good.
  def drawn_by_the_last_build(picture)
    FileUtils.mkdir_p(Music::Thumbnail.root)

    File.join(Music::Thumbnail.root, "#{MediaFile.signature(picture)}-64.jpg").tap do |sharp|
      File.binwrite(sharp, Ffmpeg.new.thumbnail(picture, size: 64))
      File.utime(File.atime(picture), File.mtime(picture), sharp)
    end
  end
end
