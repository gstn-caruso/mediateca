require "test_helper"

class SingingAlongTest < ActionDispatch::IntegrationTest
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR),
                           title: "Mundo Guanaco", artist:)
    @timed = track("Desencuentro", "01 - Desencuentro.flac")
    @wordless = track("El Pibe Tigre", "03 - El pibe tigre.flac")
  end

  # The panel follows the song, so it is handed a time for every line — and told
  # that it can follow at all.
  test "the words arrive with the moment each one is sung" do
    listening_as

    get track_lyrics_path(@timed)

    assert_response :success
    assert body["synced"]
    assert_equal [ 1.0, "La primera línea" ], body["lines"].first.values_at("at", "text")
  end

  # Most of the record has no .lrc beside it, and the panel has to be able to
  # tell "nobody wrote these down" from "the server fell over".
  test "a song nobody wrote the words for says so" do
    listening_as

    get track_lyrics_path(@wordless)

    assert_response :not_found
  end

  # The words are only for whoever is listening, like everything else here.
  test "nobody who has not sat down gets the words" do
    get track_lyrics_path(@timed)

    assert_redirected_to profiles_path
  end

  private

  def track(title, file)
    Track.create!(title:, path: File.join(@album.directory, file), album: @album)
  end

  def body
    JSON.parse(response.body)
  end
end
