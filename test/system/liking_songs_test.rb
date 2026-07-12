require "application_system_test_case"

class LikingSongsTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    @gaston = listening_as
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

    # The heart fills in place now rather than reloading the page, so waiting for
    # it is what says the heart was given. And "Desencuentro" is on the record's
    # own page too — asserting the song's name proved nothing about having got to
    # Liked Songs, so a navigation that had not landed yet went unnoticed and the
    # rest of the test ran against the album.
    click_on "Like Desencuentro"
    assert_selector "button[aria-label='Unlike Desencuentro']"

    within("nav") { click_on "Liked Songs" }
    assert_selector "h1", text: "Liked Songs"
    assert_text "Desencuentro"

    click_on "Unlike Desencuentro"

    assert_text "Songs you heart show up here"
  end

  test "an album is hearted from its own page" do
    visit album_path(@album)

    click_on "Like Mundo Guanaco"

    assert_selector "button[aria-label='Unlike Mundo Guanaco']"
  end

  # Somebody pressing a heart is telling you about a song, not asking to be taken
  # somewhere. It used to be a whole page fetched and redrawn: the scroll jumped
  # back to the top of the record, and the history filled with the same URL, once
  # per heart — so Back walked you through your own hearting.
  test "hearting a song goes nowhere: the heart changes and the page stays put" do
    visit album_path(@album)
    was = page.evaluate_script("history.length")

    click_on "Like Desencuentro"

    assert_selector "button[aria-label='Unlike Desencuentro']"
    assert_equal was, page.evaluate_script("history.length"),
      "the heart pushed an entry onto the history: it navigated"
  end

  # And a song added to a playlist says where it went. It used to say nothing at
  # all — the menu closed because the page underneath it had been replaced.
  test "a song added to a playlist says which one it landed in" do
    @gaston.playlists.create!(name: "Asado")
    visit album_path(@album)

    find("summary[aria-label='Add Desencuentro to a playlist']").click
    click_on "Asado"

    assert_text "In Asado"
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
