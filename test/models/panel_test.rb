require "test_helper"

# How wide a listener keeps a panel. Nobody has ever dragged one, and that
# silence is the ordinary case — exactly as it is for a standing.
class PanelTest < ActiveSupport::TestCase
  test "a panel nobody has touched is the width it was born" do
    assert_equal Panel::BORN, gaston.width_of("queue")
  end

  test "a panel widened is a panel remembered" do
    gaston.widens("queue", to: 360)

    assert_equal 360, gaston.width_of("queue")
  end

  # Dragged, let go, dragged again — one panel, one width. The row is replaced,
  # not added to, the way a standing is.
  test "widening the same panel twice leaves one row" do
    gaston.widens("queue", to: 360)
    gaston.widens("queue", to: 400)

    assert_equal 400, gaston.width_of("queue")
    assert_equal 1, gaston.panels.count
  end

  test "the panels are widened one at a time, and do not drag each other" do
    gaston.widens("queue", to: 360)

    assert_equal 360, gaston.width_of("queue")
    assert_equal Panel::BORN, gaston.width_of("library")
  end

  # The whole point of it hanging off the listener: the house does not agree
  # about how wide anything should be, and nobody has to.
  test "one listener widening a panel does not widen it for anybody else" do
    gaston.widens("queue", to: 360)

    assert_equal Panel::BORN, Profile.create!(name: "Ana").width_of("queue")
  end

  # The hand is held inside the room by the browser, but the request is not the
  # hand: anybody can send this app any number they like. A panel wider than the
  # room, or narrower than the things standing in it, is not a panel — so the
  # width is held between its two ends here, where it is written down, and not
  # only out there where it was dragged.
  test "a panel cannot be dragged narrower than it can be read" do
    gaston.widens("queue", to: 20)

    assert_equal Panel::NARROWEST, gaston.width_of("queue")
  end

  test "a panel cannot be dragged wider than the room it stands in" do
    gaston.widens("queue", to: 9999)

    assert_equal Panel::WIDEST, gaston.width_of("queue")
  end

  # And the other question a panel is asked, which it is asked when the content is
  # folded away and there is nothing left for it to have a width beside. A room
  # nobody has divided is divided in the proportion the panels are kept at — which
  # for a listener who has touched nothing is panels of a size.
  test "a room nobody has divided is divided by the widths it is kept at" do
    assert_equal Panel::BORN, gaston.share_of("queue")

    gaston.widens("queue", to: 400)

    assert_equal 400, gaston.share_of("queue")
  end

  test "a room divided is a room remembered" do
    gaston.gives("queue", share: 900)

    assert_equal 900, gaston.share_of("queue")
  end

  # A panel is one thing asked two questions, not two things. How much of an empty
  # room it takes says nothing about how wide it stands beside a page — and the page
  # is coming home.
  test "dividing an empty room does not touch the width the panel stands at" do
    gaston.widens("queue", to: 400)
    gaston.gives("queue", share: 900)

    assert_equal 400, gaston.width_of("queue")
    assert_equal 1, gaston.panels.count
  end

  # And a share arriving first brings the width the panel was born at with it,
  # because that is the width it has: nobody has dragged it in a room that still
  # had a page in it to drag it against.
  test "a room divided before any panel was widened leaves the widths where they were" do
    gaston.gives("queue", share: 900)

    assert_equal Panel::BORN, gaston.width_of("queue")
  end

  test "a share nobody could have dragged is held at the end of its rope" do
    gaston.gives("queue", share: 9_999_999)

    assert_equal Panel::MOST_SHARE, gaston.share_of("queue")
  end

  # There are four panels and there will not be a fifth by asking for one.
  test "a panel nobody has ever heard of is not a panel" do
    assert_raises(ArgumentError) { gaston.widens("larder", to: 300) }
  end

  test "a panel nobody has ever heard of has no width either" do
    assert_raises(ArgumentError) { gaston.width_of("larder") }
  end

  test "a panel nobody has ever heard of has no share of the room" do
    assert_raises(ArgumentError) { gaston.gives("larder", share: 300) }
    assert_raises(ArgumentError) { gaston.share_of("larder") }
  end

  private

  def gaston
    @gaston ||= Profile.create!(name: "Gastón")
  end
end
