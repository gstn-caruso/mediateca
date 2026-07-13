require "application_system_test_case"

# The player is the one pane that floats free of the layout — and now it floats
# where it is put. It can be dragged anywhere in the room, and pushed into the
# floor it stops being a pill: it becomes the bar across the foot of the room,
# the whole width of it.
#
# None of this needs a song. Where the player sits is not a question about what
# is playing, so these tests never put anything on.
class MovingThePlayerTest < ApplicationSystemTestCase
  setup do
    listening_as
    visit root_path
    assert_selector "#player"
  end

  test "the player can be dragged anywhere" do
    was = the_player

    drag_the_player by_x: -220, by_y: -260

    now = the_player
    assert_in_delta was["left"] - 220, now["left"], 2, "the player did not follow the pointer sideways"
    assert_in_delta was["top"] - 260, now["top"], 2, "the player did not follow the pointer up"
  end

  # The pill already rests a touch above the bottom, so docking cannot be "you
  # dragged it downwards". It is the push: the player stops at the floor, the
  # pointer keeps going, and when the pointer reaches the bottom edge the pill
  # gives way to a bar.
  test "pushed into the floor, it takes the whole row" do
    dock_the_player

    player = the_player
    assert_in_delta 0, player["left"], 1, "the docked player does not start at the near edge of the row"
    assert_in_delta player["room"], player["right"], 1, "the docked player does not reach the far edge of the row"
    assert_in_delta player["floor"], player["bottom"], 1, "the docked player is not standing on the floor"
  end

  # A bar across the foot of the room is the foot of the room: what is above it
  # ends where it begins. A bar that merely hovers there covers the bottom of
  # every panel it crosses — the last song on the list, the last row of the rail —
  # and those are rows somebody meant to be able to read and press.
  test "docked, it takes a row rather than standing over one" do
    was = the_content

    dock_the_player

    now = the_content
    assert_operator now["bottom"], :<=, the_player["top"] + 1, "the bar is standing over the content"
    assert_operator now["height"], :<, was["height"], "the content did not give the bar a row of its own"
  end

  # The empty inch under the songs, and the fade that dissolves them into it,
  # are both there because a pill floats over the foot of the list. A bar
  # standing in its own row floats over nothing, so the list runs to its own foot.
  test "docked, nothing is left hanging over the songs" do
    dock_the_player

    assert_no_selector ".scroll-edge"
    assert_operator the_content["clearance"], :<, 32,
                    "the list still keeps a pill's worth of empty room under it"
  end

  test "pulled back up off the floor, it is a pill again" do
    dock_the_player

    drag_the_player by_x: -80, by_y: -300

    player = the_player
    assert_operator player["width"], :<, player["room"], "the player is still as wide as the row"
    assert_operator player["bottom"], :<, player["floor"] - 100, "the player is still standing on the floor"
  end

  # A player dragged past the edge of the window would be gone for good: it is
  # the only transport there is, and there is no way to reach what you cannot
  # see. So the room holds it.
  test "it cannot be dragged out of reach" do
    grip = the_grip
    room = the_player

    # The pointer itself cannot leave the window — Chrome will not take it there —
    # so the push is into the far corner, which is enough: the hand holds the
    # player by the middle, and a player held into the corner hangs its whole
    # right-hand side over the edge unless something is holding it back.
    drag_the_player by_x: room["room"] - grip["x"] - 2, by_y: 2 - grip["y"]

    player = the_player
    assert_operator player["right"], :<=, player["room"] + 1, "the player is hanging off the right of the room"
    assert_operator player["top"], :>=, -1, "the player is hanging off the top of the room"
  end

  # The transport is pressed, not dragged. A hand that presses Play and slides a
  # little must not fling the player across the room — and the scrubber, which is
  # dragged for a living, has to stay the scrubber.
  test "the controls are not handles" do
    was = the_player

    drag_from "button[aria-label='Play or pause']", by_x: -200, by_y: -200
    drag_from "[data-player-target='progress']", by_x: -200, by_y: -200

    now = the_player
    assert_in_delta was["left"], now["left"], 1, "pressing a control dragged the player sideways"
    assert_in_delta was["top"], now["top"], 1, "pressing a control dragged the player up"
  end

  # Where the player was left is a choice, and a reload is not somebody changing
  # their mind. #player rides through a Turbo visit on its own — it is permanent —
  # but a cold load builds it again from the server's HTML, which knows nothing
  # about it, so the choice is written down and read back.
  test "where it was left is where it comes back" do
    drag_the_player by_x: -180, by_y: -240
    spot = the_player

    visit root_path

    came_back = the_player
    assert_in_delta spot["left"], came_back["left"], 1, "the player came back somewhere else"
    assert_in_delta spot["top"], came_back["top"], 1, "the player came back somewhere else"

    dock_the_player
    visit root_path

    assert_in_delta the_player["room"], the_player["width"], 1, "the player came back undocked"
  end

  private

  # Where the player is, and the room it is in.
  def the_player
    page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("#player").getBoundingClientRect()
        return {
          left: box.left, top: box.top, right: box.right, bottom: box.bottom,
          width: box.width, height: box.height,
          room: window.innerWidth, floor: window.innerHeight
        }
      })()
    JS
  end

  # The panel the songs are on: the room a docked bar has to be taking out of it,
  # and the empty inch it keeps under them for a pill to float over.
  def the_content
    page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector("main")
        const box = main.getBoundingClientRect()
        return {
          top: box.top, bottom: box.bottom, height: box.height,
          clearance: parseFloat(getComputedStyle(main).paddingBottom)
        }
      })()
    JS
  end

  # Somewhere on the player that is not a control — the line that says nothing is
  # playing. That is what a hand reaches for to move it, and it is the one part
  # of the pill that is always there.
  def the_grip
    page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector("#player [data-player-target='idle']").getBoundingClientRect()
        return { x: Math.round(box.left + box.width / 2), y: Math.round(box.top + box.height / 2) }
      })()
    JS
  end

  def drag_the_player(by_x:, by_y:)
    drag_from "#player [data-player-target='idle']", by_x:, by_y:
  end

  # A drag is a press, a journey and a release. The journey is told in two legs
  # rather than one leap, because a pointer that teleports is not a pointer
  # anybody's hand ever made.
  def drag_from(selector, by_x:, by_y:)
    half_x = by_x / 2
    half_y = by_y / 2

    page.driver.browser.action
      .click_and_hold(find(selector).native)
      .move_by(half_x, half_y)
      .move_by(by_x - half_x, by_y - half_y)
      .release
      .perform
  end

  # The push into the floor: the pointer is driven all the way down to the bottom
  # edge of the window, which is what asks for the bar.
  def dock_the_player
    grip = the_grip
    floor = page.evaluate_script("window.innerHeight")

    drag_the_player by_x: 0, by_y: floor - grip["y"] - 2
  end
end
