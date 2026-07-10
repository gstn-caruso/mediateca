require "application_system_test_case"

class KeepingPlaylistsInTheBrowserTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
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

  test "a playlist is made in the sidebar, filled from an album, and played" do
    visit album_path(@album)

    fill_in "New playlist", with: "Road trip"
    click_on "Create"
    assert_text "Nothing here yet"

    visit album_path(@album)
    add "Desencuentro", to: "Road trip"

    within("nav") { click_on "Road trip" }
    assert_text "Desencuentro"

    click_on "Play Road trip"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  test "a song is moved, then taken out again" do
    visit album_path(@album)
    fill_in "New playlist", with: "Road trip"
    click_on "Create"

    visit album_path(@album)
    add "Desencuentro", to: "Road trip"
    add "El Pibe Tigre", to: "Road trip"

    within("nav") { click_on "Road trip" }
    click_on "Move El Pibe Tigre up"

    # A waiting matcher, because Turbo has to come back before the order is real.
    assert_selector "ol > li:first-child", text: "El Pibe Tigre"
    assert_equal [ "El Pibe Tigre", "Desencuentro" ], titles

    click_on "Remove Desencuentro"

    assert_no_selector "ol", text: "Desencuentro"
    assert_equal [ "El Pibe Tigre" ], titles
  end

  private

  def add(track, to:)
    find("summary[aria-label='Add #{track} to a playlist']").click
    within("details[open]") { click_on to }
  end

  def titles
    all("[data-player-track] .font-medium").map(&:text)
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
