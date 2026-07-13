require "application_system_test_case"

# The way in is the menu under the avatar, beside the name and the way out — the
# one place in the app that is about the listener rather than the music.
class ConnectingLastfmInABrowserTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @gaston = listening_as
    Lastfm.api = FakeLastfm.new
  end

  test "the menu under the avatar offers Last.fm" do
    visit root_path
    open_profile_menu

    assert_link "Connect Last.fm"
    take_screenshot
  end

  test "a connected listener sees who they are over there, and gets there from the menu" do
    connected

    visit root_path
    open_profile_menu
    within("#topbar") { click_on "Scrobbling" }

    assert_selector "h1", text: "Last.fm"
    assert_link "gaston", href: "https://www.last.fm/user/gaston"
    take_screenshot
  end

  # The page says what Last.fm actually did with the listening it was handed —
  # including the part a quieter app would have swallowed.
  test "the Last.fm page owns up to what Last.fm threw away" do
    Lastfm.api = FakeLastfm.new(ignoring: 3)
    heard_a_song_long_ago
    perform_enqueued_jobs { connected }

    visit scrobbler_path

    assert_text "Last.fm threw away 1 of the songs it was handed"
    take_screenshot
  end

  test "disconnecting says so and takes the offer back" do
    connected
    visit scrobbler_path

    click_button "Disconnect Last.fm"

    assert_text "Last.fm disconnected"
    open_profile_menu
    assert_link "Connect Last.fm"
  end

  # No API account, no Last.fm: a menu item that leads nowhere is worse than no
  # menu item at all.
  test "a Mediateca nobody gave Last.fm credentials to says nothing about it" do
    Lastfm.api = FakeLastfm.new(configured: false)

    visit root_path
    open_profile_menu

    assert_no_text "Last.fm"
    assert_text "Switch profile"
  end

  private

  def connected
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end

  def heard_a_song_long_ago
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/01.flac", album:)

    @gaston.played(song, at: 2.years.ago)
  end
end
