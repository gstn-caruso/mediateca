require "application_system_test_case"

# The panels were nailed to 18rem — all four of them, the same 18rem, chosen once
# and never again. Now a hand can take a panel by its edge and give it the room it
# is short of, and the app remembers who wanted it that way.
#
# None of this needs a song. How wide the queue is kept is not a question about
# what is playing, so these tests never put anything on.
class WideningThePanelsTest < ApplicationSystemTestCase
  BORN = 288
  NARROWEST = 240
  WIDEST = 480

  setup do
    listening_as
    visit root_path
    assert_selector "#topbar"
  end

  test "the library takes the room it is given" do
    widen "#library-panel", by: 90

    assert_in_delta BORN + 90, width_of("#library-panel"), 2, "the library did not follow the hand"
  end

  test "and gives it back" do
    widen "#library-panel", by: -40

    assert_in_delta BORN - 40, width_of("#library-panel"), 2, "the library did not follow the hand back"
  end

  # The library is opened by its own edge, so a hand moving right widens it. The
  # three on the far side are opened by theirs, and there a hand moving right is
  # a hand making room for the content — the same gesture, read from the other
  # side of the room.
  test "the rails on the far side widen the other way" do
    open_the "Playing Next"

    widen "#queue-panel", by: -90

    assert_in_delta BORN + 90, width_of("#queue-panel"), 2, "the queue shrank when the hand made room for it"
  end

  # A panel narrower than this cannot say what it is for: the rows carry a face
  # and two lines, and the turn above them has three icons to fit.
  #
  # Taken out to its far end first, and only then squeezed: the pointer cannot
  # leave the window — Chrome will not take it there — and a hand starting at 288
  # has nowhere near enough room to its left to push the library past its floor.
  test "a panel cannot be squeezed past being readable" do
    widen "#library-panel", by: 600

    widen "#library-panel", by: -400

    assert_in_delta NARROWEST, width_of("#library-panel"), 2, "the library was squeezed to nothing"
  end

  # And past this it has stopped being a rail beside the content and started
  # being the content.
  test "a panel cannot be pulled wider than a rail" do
    widen "#library-panel", by: 600

    assert_in_delta WIDEST, width_of("#library-panel"), 2, "the library ate the room"
  end

  # A seam is between two things, and moving it is a trade: what one panel takes,
  # the one across it gives. It was not — the content gave, whichever seam was
  # pulled and wherever in the room it was, because the content was the leftovers
  # and the leftovers are what every drag came out of. Two rails standing side by
  # side had a seam between them that neither of them felt.
  test "a rail takes its room from the rail across the seam" do
    two_rails_up
    page = width_of("main")

    widen "#queue-panel", by: -40

    assert_in_delta BORN + 40, width_of("#queue-panel"), 2, "the queue did not follow the hand"
    assert_in_delta BORN - 40, width_of("#visualizer-panel"), 2, "the picture did not give the queue its room"
    assert_in_delta page, width_of("main"), 2, "the content paid for a drag that was not about it"
  end

  # And when the rail across the seam has nothing left to give, the room goes on
  # giving way behind it — the next panel, and the content last of all.
  #
  # A rail is born 48 pixels off its floor. A hand that could ask for nothing once
  # its neighbour was spent would be a queue frozen 48 pixels from where it began,
  # in a room with half a screen of content standing idle beside it.
  test "when the rail across the seam is spent, the room goes on giving way" do
    two_rails_up

    widen "#queue-panel", by: -600

    assert_in_delta WIDEST, width_of("#queue-panel"), 2, "the queue was frozen by the rail beside it"
    assert_in_delta NARROWEST, width_of("#visualizer-panel"), 2, "the picture did not give what it had"
  end

  # Both sides of a seam moved, so both sides of it are written down. The one that
  # gave was never touched by the hand, and it is a width its listener now keeps
  # all the same: they moved it, they just moved it from the other end.
  test "both sides of a seam are written down" do
    two_rails_up

    widen "#queue-panel", by: -40

    assert_in_delta BORN - 40, written_down("visualizer"), 2, "the picture forgot what it gave"
  end

  # The content is what all of this is beside. A hand that could go on widening
  # rails until there was nothing left to widen them beside would be a hand
  # holding a library with no music in it.
  test "the rails cannot close in on the content" do
    [ "Visualizer", "Lyrics", "Playing Next" ].each { open_the it }

    widen "#queue-panel", by: -600
    widen "#library-panel", by: 600

    assert_operator width_of("main"), :>=, 359, "the rails closed in on the content"
  end

  # A width is a choice, and a reload is not somebody changing their mind. Unlike
  # the queue and the player — which a browser remembers for itself — this one is
  # remembered by the app, for the listener: the kitchen tablet is the same
  # listener as the laptop, and it wants the same room.
  test "the width it was left at is the width it comes back at" do
    widen "#library-panel", by: 90
    kept = written_down("library")

    visit album_path(an_album)
    assert_in_delta kept, width_of("#library-panel"), 2, "the library forgot on the way to a record"

    visit root_path
    assert_in_delta kept, width_of("#library-panel"), 2, "the library forgot on a cold load"
  end

  # The whole point of it hanging off the listener rather than off the browser.
  test "one listener's room is not everybody's" do
    widen "#library-panel", by: 90
    written_down("library")

    switch_profile
    listening_as "Ana"

    assert_in_delta BORN, width_of("#library-panel"), 2, "Ana inherited somebody else's idea of a library"
  end

  # On a phone a rail does not stand beside anything — it comes over the top, and
  # takes the screen. There is no edge between two things to take hold of, so
  # there is nothing to take hold of.
  test "a phone has no edges to pull" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    visit root_path

    open_the "Playing Next"

    assert_no_selector "#queue-panel .grip", visible: true
  end

  private

  # Two rails standing side by side, which is what a seam between two panels needs.
  # The words are not one of them: a song nobody wrote them for has nothing to
  # open, so that button goes dead — and none of this needs a song.
  def two_rails_up
    open_the "Visualizer"
    open_the "Playing Next"
  end

  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  # A record to walk to, so the rail is asked to remember its width on the way to
  # a page rather than only on the one it was dragged on.
  def an_album
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR),
      title: "Mundo Guanaco", year: 1995, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album:)
    album
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end

  # The hand let go and the browser moved straight on: the width is written down
  # by a fetch nobody waited for. A test that navigates the instant it lets go can
  # outrun that write and then blame the page for forgetting — so it waits for the
  # app to have heard, which is not a sleep dressed up. It is half of what is being
  # tested: this is the width that outlives the browser it was chosen in.
  def written_down(panel)
    listener = Profile.find_by!(name: "Gastón")

    20.times do
      width = listener.reload.width_of(panel)
      return width unless width == BORN

      sleep 0.05
    end

    flunk "the #{panel} was never written down"
  end
end
