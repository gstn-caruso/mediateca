require "application_system_test_case"

# The way in is the menu under the avatar, beside the name and the way out — the
# one place in the app that is about the listener rather than the music.
class ConnectingLastfmInABrowserTest < ApplicationSystemTestCase
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

  test "a connected listener sees who they are over there, and how to stop" do
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")

    visit root_path
    open_profile_menu

    assert_text "Scrobbling"
    assert_link "gaston", href: "https://www.last.fm/user/gaston"
    assert_button "Disconnect Last.fm"
    take_screenshot
  end

  test "disconnecting says so and takes the offer back" do
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
    visit root_path
    open_profile_menu

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
end
