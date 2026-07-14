require "application_system_test_case"

class SearchingInTheBrowserTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album:)
  end

  # A result you cannot play is a catalogue entry, not a music app.
  test "a song found in the search bar plays from the results" do
    visit root_path

    fill_in "Search", with: "Desencuentro"
    find_field("Search").send_keys(:return)

    # Not "Songs": the rail says "Liked Songs" on every page in the app, so that
    # text is already on screen before the search has gone anywhere, and waiting
    # for it waits for nothing. The heading over the results is the results.
    assert_selector "h2", text: "Songs"

    # The row and its heart both answer to the song's name; the row comes first,
    # and the row is what you press to hear it.
    click_on "Desencuentro", match: :first

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
