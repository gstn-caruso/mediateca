require "application_system_test_case"

class OnAPhoneTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    page.current_window.resize_to(*PHONE)
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album: @album)
  end

  # A phone scrolls up and down. Sideways means something is wider than the
  # screen, and everything to its right is unreachable.
  test "no page scrolls sideways" do
    [ root_path, album_path(@album), likes_path, search_path(q: "Desencuentro") ].each do |page|
      visit page

      assert_no_sideways_scroll page
    end
  end

  # The sidebar is desktop-only, and it holds Liked Songs, the playlists and the
  # way out of a profile. On a phone all three have to live somewhere else.
  test "liked songs is reachable with no sidebar" do
    visit root_path

    click_on "Liked Songs"

    assert_text "Songs you heart show up here"
  end

  test "a profile can be left with no sidebar" do
    visit root_path

    click_on "Switch profile"

    assert_text "Who's listening?"
  end

  test "a song still plays" do
    visit album_path(@album)

    find("button[data-player-track]", text: "Desencuentro").click

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  private

  def assert_no_sideways_scroll(page)
    overflow = evaluate_script("document.body.scrollWidth - window.innerWidth")

    assert_operator overflow, :<=, 0, "#{page} is #{overflow}px wider than the screen"
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
