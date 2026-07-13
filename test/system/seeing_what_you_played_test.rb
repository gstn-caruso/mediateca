require "application_system_test_case"

# The counts, on the page they belong to: the record says how many turns you have
# given it, and each song how many times you have heard it.
class SeeingWhatYouPlayedTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    @songs = {
      "Desencuentro" => "01 - Desencuentro.flac",
      "Dijo El Droguero Al Drogador" => "02 - Dijo el droguero al drogador.flac",
      "El Pibe Tigre" => "03 - El pibe tigre.flac"
    }.each_with_index.map do |(title, file), at|
      Track.create!(title:, track_no: at + 1, disc_no: 1, duration: 137.0 + at, path: media(file), album: @album)
    end
  end

  test "a record you have worn out says so, and so does every song on it" do
    3.times { @songs.each { @gaston.played(it) } }
    2.times { @gaston.played(@songs.first) }

    visit album_path(@album)

    assert_text "Spun 3 times"
    within("li", text: "Desencuentro") { assert_text "5 plays" }
    within("li", text: "El Pibe Tigre") { assert_text "3 plays" }
    take_screenshot
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
