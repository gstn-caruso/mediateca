require "application_system_test_case"

# Four panels stood around a fifth thing that was never one: the content was
# simply whatever the four of them had not taken. It could not be folded away,
# because there was nothing there to fold — it was the leftovers.
#
# Now it is a panel like the rest. Fold it and the room goes to the panels that
# are left, which is the whole of the point: the queue you are reading, or the
# picture the music is drawing, gets the screen instead of a column of it.
class FoldingTheContentAwayTest < ApplicationSystemTestCase
  BORN = 288

  # Past this a panel has stopped being a rail beside the content and started
  # being the content. Nothing a hand does can take one further — so a panel
  # found wider than this is a panel that was given a room with no content in it.
  WIDEST = 480

  setup do
    listening_as
    visit root_path
    assert_selector "#topbar"
  end

  test "the content folds away" do
    open_the "Content"

    assert_no_selector "#content", visible: true
  end

  test "and comes back" do
    open_the "Content"
    open_the "Content"

    assert_selector "#content", visible: true
  end

  # Nothing stands beside nothing. With the content gone the panels that are left
  # are the room, and they are handed all of it.
  test "the panels that are left take the room" do
    open_the "Playing Next"

    open_the "Content"

    assert_operator width_of("#queue-panel"), :>, WIDEST,
                    "the queue went on standing beside a content that is not there"
  end

  # The room closing in on a panel holds it back and goes on holding it, which is
  # right: a narrowed window is not somebody changing their mind. But a content
  # that is *gone* is not a room closing in — and a room with no content in it,
  # asked how much room the content has left, will answer that it is desperately
  # short of it and start arguing the panels down to pay for it.
  #
  # There is nothing to pay for. The panels come back at the width they were left
  # at, because nobody touched them.
  test "a panel does not lose the width it was given while the content is away" do
    widen "#library-panel", by: 90

    open_the "Content"
    open_the "Content"

    assert_in_delta BORN + 90, width_of("#library-panel"), 2,
                    "the library was argued down while the content was away"
  end

  # A room with no content in it is still a room with seams in it, and for a while
  # it was not: the panels were handed the room and then held at arm's length from
  # it, with the one gesture that could have divided it taken away. This is the room
  # you fold the content away to *get* — the picture and the queue, side by side —
  # and it was the one room in the app you could not lay a finger on.
  #
  # So the seam moves, and the room stays as full as it was: what one panel takes,
  # the one across it gives.
  test "the seam between two panels can be pulled with no content in the room" do
    two_rails_up
    open_the "Content"

    was = the_room
    queue = width_of("#queue-panel")

    widen "#queue-panel", by: -120

    assert_in_delta queue + 120, width_of("#queue-panel"), 3, "the queue did not follow the hand"
    assert_in_delta was, the_room, 3, "the room is not as full as it was"
  end

  # A width is in pixels, and it has two ends: a rail narrower than 240 cannot say
  # what it is for, and one wider than 480 has stopped standing beside the content
  # and started being it. Neither of those is true of a panel with no content to
  # stand beside — it is not a rail, it is half of an empty room, and half of this
  # room is nowhere near 480 pixels.
  #
  # So what is kept here is not a width. It is a share: it says nothing on its own,
  # only how this panel stands to the one next to it. That is why it survives the
  # trip from the laptop to the kitchen tablet, where 700 pixels is the whole room.
  test "how the room was divided is how it comes back" do
    two_rails_up
    open_the "Content"

    widen "#queue-panel", by: -120
    divided = width_of("#queue-panel") / the_room
    divided_up("queue")

    visit root_path

    assert_in_delta divided, width_of("#queue-panel") / the_room, 0.02,
                    "the room forgot how it had been divided"
  end

  private

  # Two rails standing side by side, which is what a seam is between. Not the
  # words: a song nobody wrote them for has nothing to open, so that button goes
  # dead — and none of this needs a song.
  def two_rails_up
    open_the "Visualizer"
    open_the "Playing Next"
  end

  # Everything left standing, added up. With the content folded away the panels
  # *are* the room, so this is the room — and it has to come back the same whatever
  # a hand does inside it.
  def the_room
    page.evaluate_script(<<~JS)
      [ ...document.getElementById("panels").children ]
        .filter((panel) => panel.classList.contains("panel") && panel.offsetParent)
        .reduce((all, panel) => all + panel.getBoundingClientRect().width, 0)
    JS
  end

  # The hand let go and the browser moved straight on: how the room was divided is
  # written down by a fetch nobody waited for. A test that navigates the instant it
  # lets go can outrun that write and then blame the page for forgetting.
  # A share nobody has set falls back to the width the panel is kept at, which is
  # the width it was born at, so that is what it says until the write lands.
  def divided_up(panel)
    listener = Profile.find_by!(name: "Gastón")

    20.times do
      share = listener.reload.share_of(panel)
      return share unless share == BORN

      sleep 0.05
    end

    flunk "how the room was divided was never written down"
  end

  # A grip is the edge between two things, and the panel standing first in the room
  # has only the wall on its far side. There is nobody there to trade with, so there
  # is no seam — and a handle a hand could take hold of and pull on and move nothing
  # with is a handle that is lying.
  #
  # This is the room in the picture: the library shut, the content folded, and the
  # picture and the queue standing in what is left. One seam, between the two of
  # them, and it is the queue's — the picture's far edge is where the app ends.
  test "the panel standing first in the room has no edge to pull" do
    two_rails_up
    open_the "Library"
    open_the "Content"

    assert_no_selector "#visualizer-panel .grip", visible: true
    assert_selector "#queue-panel .grip", visible: true
  end

  # Folded is a choice, and a reload is not somebody changing their mind.
  test "folded is how it comes back" do
    open_the "Content"

    visit root_path

    assert_no_selector "#content", visible: true
  end

  # A phone's content *is* the phone. The rails come over the top of it rather
  # than standing beside it and the library is not there at all, so there is
  # nothing to hand the room to: folding it would leave a listener holding an
  # empty window, with the button that emptied it the only way back out.
  test "a phone has nothing to fold" do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: 390, height: 844, deviceScaleFactor: 2, mobile: true)
    visit root_path

    assert_no_selector "#topbar button[aria-label='Content']", visible: true
    assert_selector "#content", visible: true
  end
end
