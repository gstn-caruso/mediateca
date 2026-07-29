require "application_system_test_case"

class KeepingPlaylistsInTheBrowserTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    profile = listening_as
    profile.playlists.create!(name: "Road trip")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album: @album)
    Track.create!(title: "El Pibe Tigre", track_no: 2, disc_no: 1, duration: 139.0,
                  path: media("03 - El pibe tigre.flac"), album: @album)
  end

  test "a playlist is filled from an album, and played" do
    visit album_path(@album)
    add "Desencuentro", to: "Road trip"

    in_the_library("Playlists") { click_on "Road trip" }
    assert_text "Desencuentro"

    click_on "Play Road trip"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  private

  def add(track, to:)
    find("summary[aria-label='Add #{track} to a playlist']").click
    within("details[open]") { click_on to }
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
