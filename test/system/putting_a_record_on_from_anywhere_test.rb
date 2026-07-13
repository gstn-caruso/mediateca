require "application_system_test_case"

# Music used to start in exactly one place: a record's own page, where the songs
# are on the screen and the queue is the rows. Everywhere else — the rail, an
# artist's page — you could only ever get closer to the music, never play it.
#
# So the things that can be put on now say so, and the player goes and asks them
# for their songs.
class PuttingARecordOnFromAnywhereTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist: @artist, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album: @album)
    Track.create!(title: "Como los bueyes", track_no: 2, disc_no: 1, duration: 140.0,
                  path: media("04 - Como los bueyes.opus"), album: @album)
  end

  test "a record is put on from the rail, without ever opening it" do
    visit root_path

    in_the_library("Albums") { click_on "Play Mundo Guanaco" }

    assert_playing "Desencuentro"
  end

  test "an artist is put on from the rail, and their shelf plays" do
    visit root_path

    in_the_library("Artists") { click_on "Play Almafuerte" }

    assert_playing "Desencuentro"
  end

  # The whole shelf, from an artist's own page — where there is not a single song
  # row to press. Scoped to the page, because the rail is standing right there
  # offering the same artist, and both buttons say the same true thing.
  test "an artist is put on from their own page" do
    visit artist_path(@artist)

    within("main") { click_on "Play Almafuerte" }

    assert_playing "Desencuentro"
  end

  # Whatever it starts with, it is one of theirs — and the queue behind it is the
  # whole shelf, not the one song that happened to be dealt first.
  test "an artist can be shuffled from their own page" do
    visit artist_path(@artist)

    within("main") { click_on "Shuffle Almafuerte" }

    assert_selector "[data-player-target='title']", text: /Desencuentro|Como los bueyes/
  end

  private

  def assert_playing(title)
    assert_selector "[data-player-target='title']", text: title
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
