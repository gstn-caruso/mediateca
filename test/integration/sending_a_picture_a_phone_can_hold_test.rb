require "test_helper"

# The library rail draws every artist and every record at forty-four pixels a
# side, and it was sending the whole scan to do it — seventy-five sleeves, each
# one a megabyte or two, downloaded and then decoded, to fill a column of
# thumbnails. On the machine this was written on, nobody noticed. On the cheap
# Android in the kitchen it is the app.
#
# So a picture arrives at the size it is going to be drawn at, and the page says
# which size that is.
class SendingAPictureAPhoneCanHoldTest < ActionDispatch::IntegrationTest
  include Sleeves
  include Pictures

  SCAN = 600

  # The sleeves a test draws are the music, as far as this test is concerned: the
  # app only serves what is under the media root, and these have to be served.
  setup do
    @nas = Rails.configuration.x.media_root
    Rails.configuration.x.media_root = sleeves.to_s

    listening_as
    @artist = Artist.create!(name: "Elliott Smith", portrait_path: in_the_portraits(photograph({ "#1e6ad4" => 1.0 }, SCAN)))
    @album = Album.create!(directory: "/music/figure-8", title: "Figure 8", year: 2000, artist: @artist,
                           cover_path: sleeve({ "#c8102e" => 1.0 }, SCAN))
  end

  teardown { Rails.configuration.x.media_root = @nas }

  # A face lives under storage/ and a sleeve lives with the music, and each is
  # served out of its own root. A photograph that a test leaves among the records
  # is a photograph the app is right to refuse.
  def in_the_portraits(picture)
    root = Rails.configuration.x.portraits_root
    FileUtils.mkdir_p(root)

    File.join(root, File.basename(picture)).tap { FileUtils.cp(picture, it) }
  end

  test "a sleeve arrives at the size it was asked for" do
    get album_cover_path(@album, size: 96)

    assert_response :success
    assert_equal [ 96, 96 ], measure(kept(response.body))
  end

  test "a photograph arrives at the size it was asked for" do
    get artist_portrait_path(@artist, size: 96)

    assert_response :success
    assert_equal [ 96, 96 ], measure(kept(response.body))
  end

  # The picture itself is still there for whoever actually wants to look at it.
  test "a picture nobody sized arrives whole" do
    get album_cover_path(@album)

    assert_response :success
    assert_equal [ SCAN, SCAN ], measure(kept(response.body))
  end

  test "a size nobody draws is not drawn" do
    get album_cover_path(@album, size: 5000)

    assert_response :success
    assert_equal [ SCAN, SCAN ], measure(kept(response.body)),
      "a URL that can ask for any size can ask the NAS to draw ten thousand of them"
  end

  # A cover.jpg that is not a JPEG is one of the things on a NAS. The page still
  # wants a picture in that row, and gets the file — which is what it got before
  # any of this existed.
  test "a picture ffmpeg cannot read is handed over as it is" do
    @album.update!(cover_path: sleeves.join("not-a-picture.jpg").tap { it.write("hello") }.to_s)

    get album_cover_path(@album, size: 96)

    assert_response :success
    assert_equal "hello", response.body
  end

  # The media root is the trust boundary, and asking for a size must not be a way
  # through it. The old test for this pointed a cover at /etc/passwd and was
  # answered 403 — but only because ffmpeg cannot read /etc/passwd. A picture it
  # CAN read, sitting outside the root, is the case that matters: drawing it small
  # first and checking the root afterwards is checking the root of a file we have
  # already opened, decoded and re-encoded.
  test "a size is not a way around the media root" do
    outside = Rails.root.join("tmp/outside-the-root-#{Process.pid}.png")
    FileUtils.cp(sleeve({ "#c8102e" => 1.0 }, SCAN), outside)
    @album.update_column(:cover_path, outside.to_s)

    get album_cover_path(@album, size: 96)

    assert_response :forbidden
  end

  test "the rail asks for the forty-four pixels it draws, and not for the scan" do
    get root_path

    pictures = css_select("nav img")

    assert_predicate pictures, :any?
    assert pictures.all? { it["src"].include?("size=96") },
      "the rail is drawing 44px rows and still asking for the whole scan"
  end
end
