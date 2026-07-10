require "test_helper"
require "fileutils"

class ShowingArtistsTest < ActionDispatch::IntegrationTest
  setup do
    listening_as
    @artist = Artist.create!(name: "Almafuerte")
    @root = Rails.configuration.x.portraits_root
    FileUtils.mkdir_p(@root)
  end

  test "an artist with a photograph is served it" do
    @artist.update!(portrait_path: photograph("of almafuerte"))

    get artist_portrait_path(@artist)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_equal "of almafuerte", response.body
  end

  # A record is not a face. Nobody photographed this one, and the page says so
  # rather than reaching for the sleeve of one of their albums.
  test "an artist nobody photographed shows an initial, not a record sleeve" do
    get artist_path(@artist)

    assert_response :success
    assert_no_match "/portrait", response.body
    assert_match %r{>\s*A\s*<}, response.body
  end

  test "asking for a portrait that was never taken answers 404" do
    get artist_portrait_path(@artist)

    assert_response :not_found
  end

  # The portraits root is a trust boundary too: the path comes out of the
  # database, and the database is filled by whatever answered over the wire.
  test "a portrait path that escapes the portraits root is refused" do
    @artist.update_column(:portrait_path, "/etc/passwd")

    get artist_portrait_path(@artist)

    assert_response :forbidden
  end

  test "the portrait URL names the file, so a reused id cannot serve the wrong face" do
    @artist.update!(portrait_path: photograph("of almafuerte"))

    get artist_path(@artist)

    assert_match "/portrait?v=#{MediaFile.signature(@artist.portrait_path)}", CGI.unescapeHTML(response.body)
  end

  private

  def photograph(bytes)
    File.join(@root, "#{Digest::SHA256.hexdigest(bytes).first(16)}.jpg").tap do |path|
      File.binwrite(path, bytes)
    end
  end
end
