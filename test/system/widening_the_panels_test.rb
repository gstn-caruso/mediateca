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

  def open_the(rail)
    within("#topbar") { find("button[aria-label='#{rail}']").click }
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

  def width_of(selector)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().width")
  end

  # A drag is a press, a journey and a release — and the journey is told in two
  # legs rather than one leap, because a pointer that teleports is not a pointer
  # anybody's hand ever made.
  def widen(panel, by:)
    half = by / 2

    page.driver.browser.action
      .click_and_hold(find("#{panel} .grip", visible: :all).native)
      .move_by(half, 0)
      .move_by(by - half, 0)
      .release
      .perform
  end
end
