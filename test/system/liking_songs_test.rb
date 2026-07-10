require "application_system_test_case"

class LikingSongsTest < ApplicationSystemTestCase
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
  end

  test "a hearted song lands in Liked Songs, and an unhearted one leaves" do
    visit album_path(@album)

    click_on "Like Desencuentro"
    within("nav") { click_on "Liked Songs" }

    assert_text "Desencuentro"

    click_on "Unlike Desencuentro"

    assert_text "Songs you heart show up here"
  end

  test "an album is hearted from its own page" do
    visit album_path(@album)

    click_on "Like Mundo Guanaco"

    assert_selector "button[aria-label='Unlike Mundo Guanaco']"
  end

  # The play is recorded by a fetch nothing waits on, so the test has to.
  test "a song that played shows up under Recently played" do
    visit album_path(@album)
    find("button[data-player-track]", text: "Desencuentro").click
    wait_for_a_play

    visit root_path

    assert_text "Recently played"
    assert_selector "a", text: "Mundo Guanaco"
  end

  private

  def wait_for_a_play
    Timeout.timeout(Capybara.default_max_wait_time) { sleep 0.05 until Play.any? }
  rescue Timeout::Error
    flunk "the player never recorded the play"
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
