require "application_system_test_case"

# The report. Not "you played 127,231 songs" — every service says that. The one
# fact only a library can hand you is the other one: how much of what you love it
# hasn't got.
class TheReportInABrowserTest < ApplicationSystemTestCase
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/1.flac", album:)

    # Each of the three lists needs exactly one thing to draw on: a play of an
    # owned song old enough to count as forgotten fills both "On repeat" (any
    # play of what you own) and "You've forgotten these" (owned, and not played
    # since); a play of a gap fills "Not on the disk".
    @gaston.played(song, at: 2.years.ago)
    @gaston.heard_elsewhere(absence: @gaston.misses(artist: "Pappo", title: "Desconfío"), at: 1.day.ago, from: "lastfm")
  end

  test "the three lists it is owed can be made" do
    visit report_path
    scroll_to(find("h2", text: "Three lists you're owed"))
    take_screenshot

    click_button "Make them"

    # The flash, not the bare word: this page's own prose already says "Made out
    # of the history", so waiting on "Made" is waiting on something that was
    # already there — which is to say waiting for nothing. The lists are not made
    # yet, the visit is still in flight, and the rail gets turned to the lists in
    # the middle of the swap: the turn lands on a body that is about to be thrown
    # away, and the one that replaces it comes back on the turn it was left on.
    # The links are there, written and hidden, which is exactly what the failure
    # said — a link found, and no text to it.
    assert_selector "[role=status]", text: "Made"
    in_the_library("Playlists") do
      assert_link "Not on the disk"
      assert_link "On repeat"
    end
  end
end
