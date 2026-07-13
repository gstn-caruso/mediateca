require "application_system_test_case"

# The two pages a decade of listening earns you.
class ReadingYourHistoryInABrowserTest < ApplicationSystemTestCase
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

    4.times { |at| @gaston.played(@song, at: (at + 1).hours.ago) }
    2.times { |at| @gaston.played(@song, at: (at + 1).days.ago) }
    heard "Pappo", "Desconfío", times: 9
    heard "Fito Páez", "11 y 6", times: 6
    heard "La Renga", "El Revelde", times: 3
  end

  test "the history is a day at a time, and says what came from elsewhere" do
    in_the_library("Playlists") { click_on "History" }

    assert_selector "h1", text: "History"
    assert_text "Desencuentro"
    assert_text "Desconfío"
    assert_selector "[data-history-song]", text: /last\.fm/i
    take_screenshot
  end

  test "the stats say who you actually listen to, owned or not" do
    visit statistics_path

    assert_selector "h1", text: "Stats"
    assert_text "Pappo"
    assert_text "Almafuerte"
    take_screenshot
  end

  private

  def heard(who, what, times:)
    gap = @gaston.misses(artist: who, title: what)

    times.times { |at| @gaston.heard_elsewhere(absence: gap, at: (at + 1).hours.ago, from: "lastfm") }
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
