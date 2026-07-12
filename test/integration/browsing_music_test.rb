require "test_helper"

class BrowsingMusicTest < ActionDispatch::IntegrationTest
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995, genre: "", album_type: "album",
      disc_total: 1, artist: @artist, cover_path: media("cover.jpg")
    )
    @track = Track.create!(
      title: "Desencuentro", track_no: 2, disc_no: 1, duration: 136.9,
      path: media("01 - Desencuentro.flac"), album: @album
    )
  end

  test "the front page lists the artists" do
    get root_path

    assert_response :success
    assert_match "Almafuerte", response.body
  end

  test "an artist shows its albums" do
    get artist_path(@artist)

    assert_response :success
    assert_match "Mundo Guanaco", response.body
  end

  test "an album shows its tracks" do
    Track.create!(title: "Dijo El Droguero", track_no: 1, disc_no: 1, path: media("otro.flac"), album: @album)

    get album_path(@album)

    assert_response :success
    assert_operator response.body.index("Dijo El Droguero"), :<, response.body.index("Desencuentro"),
      "tracks have to come out in playback order, not creation order"
  end

  test "an album's cover is served as an image" do
    get album_cover_path(@album)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  # 3 of the NAS's 75 albums point to covers that are no longer on disk.
  test "a cover that is no longer on disk returns 404" do
    @album.update!(cover_path: media("missing.jpg"))

    get album_cover_path(@album)

    assert_response :not_found
  end

  test "an album with no cover returns 404" do
    @album.update!(cover_path: nil)

    get album_cover_path(@album)

    assert_response :not_found
  end

  test "a track is served as audio" do
    get track_stream_path(@track)

    assert_response :success
    assert_equal "audio/flac", response.media_type
  end

  # Without Range there's no seek: dragging the player's progress bar becomes
  # impossible and the browser has to download the whole FLAC to start.
  # (Rack 3 normalizes headers to lowercase.)
  test "a track responds to a Range request with partial content" do
    get track_stream_path(@track), headers: { "Range" => "bytes=0-9" }

    assert_response :partial_content
    assert_equal "bytes 0-9/#{File.size(@track.path)}", response.headers["content-range"]
    assert_equal 10, response.body.bytesize
  end

  test "a track announces that it accepts ranges, so the player offers seek" do
    get track_stream_path(@track)

    assert_response :success
    assert_equal "bytes", response.headers["accept-ranges"]
  end

  test "a track whose file is no longer on disk returns 404" do
    @track.update!(path: media("deleted.flac"))

    get track_stream_path(@track)

    assert_response :not_found
  end

  test "a track whose path escapes the media root returns 403" do
    @track.update_column(:path, "/etc/passwd")

    get track_stream_path(@track)

    assert_response :forbidden
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
