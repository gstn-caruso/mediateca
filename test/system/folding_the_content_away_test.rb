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

  # And while it is away there is no seam between two things anywhere in the room,
  # so there is nothing to take hold of.
  test "there are no edges to pull in a room with no content" do
    open_the "Playing Next"

    open_the "Content"

    assert_no_selector "#queue-panel .grip", visible: true
    assert_no_selector "#library-panel .grip", visible: true
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
