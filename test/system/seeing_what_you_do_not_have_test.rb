require "application_system_test_case"

# What the gaps look like: grey, quiet, and doing nothing. They are not offers and
# they are not mistakes — they are the shape of the distance between what somebody
# listens to and what is on their disk.
class SeeingWhatYouDoNotHaveInABrowserTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    @song = Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 137.0,
                          path: media("01 - Desencuentro.flac"), album: @album)
  end

  test "a list brought home from Spotify keeps the songs you do not own, drawn grey" do
    list = @gaston.playlists.create!(name: "Canciones favoritas")
    list.add(@song)
    [ [ "Pappo", "Desconfío" ], [ "Fito Páez", "11 y 6" ], [ "La Renga", "El Revelde" ] ].each_with_index do |(who, what), at|
      list.entries.create!(absence: @gaston.misses(artist: who, title: what), position: at + 2)
    end

    visit playlist_path(list)

    assert_text "Desencuentro"
    assert_text "Desconfío"
    assert_text "3 you don't have"
    take_screenshot
  end

  test "the library shows the artists it has no record by at all" do
    { "Fito Páez" => 58, "La Renga" => 55, "Bunbury" => 48 }.each do |who, songs|
      songs.times { |at| @gaston.misses(artist: who, title: "Song #{at}") }
    end

    visit root_path

    assert_text "Not here yet"
    assert_text "Fito Páez"
    assert_text "58 songs you don't have"
    take_screenshot
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
