require "application_system_test_case"

# The one page that is about the listener rather than the music.
#
# Its signature is a shelf: whoever you play most, drawn as record spines, as tall
# as you play them. The hollow ones are the artists you listen to and own no record
# by — which no other music app would ever show you, because every other music app
# is a shop and has nothing to gain by naming what it does not have.
class YourOwnPageTest < ApplicationSystemTestCase
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", year: 1995, artist:)
    song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/1.flac", album:)

    12.times { |at| @gaston.played(song, at: (at + 1).hours.ago) }
    heard "Pappo", times: 34
    heard "Fito Páez", times: 27
    heard "La Renga", times: 19
    heard "Bunbury", times: 9
    heard "Spinetta", times: 5
  end

  test "the shelf shows what you play, and stands the ones you do not own hollow" do
    open_profile_menu
    within("#topbar") { click_on "Gastón" }

    assert_selector "h1", text: "Gastón"
    assert_text "Your shelf"
    assert_link "Almafuerte"
    assert_text "Pappo"
    assert_text(/songs played/i)

    # The shelf is the point of the page, and it is below the fold.
    scroll_to(find("h2", text: "Your shelf"))
    take_screenshot
  end

  private

  def heard(who, times:)
    times.times do |at|
      gap = @gaston.misses(artist: who, title: "Song #{at}")
      @gaston.heard_elsewhere(absence: gap, at: (at + 1).hours.ago, from: "lastfm")
    end
  end
end
