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

  # There are four panels and there will not be a fifth by asking for one.
  test "a panel nobody has ever heard of is not a panel" do
    assert_raises(ArgumentError) { gaston.widens("larder", to: 300) }
  end

  test "a panel nobody has ever heard of has no width either" do
    assert_raises(ArgumentError) { gaston.width_of("larder") }
  end

  private

  def gaston
    @gaston ||= Profile.create!(name: "Gastón")
  end
end
