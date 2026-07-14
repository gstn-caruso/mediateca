require "test_helper"

# A hand let go of a panel's edge. Nothing navigated: the panel is already the
# width the hand made it, and the browser has nothing to be told. This is only
# the writing down.
class WideningAPanelTest < ActionDispatch::IntegrationTest
  setup { @gaston = listening_as }

  test "a panel let go of is a panel written down" do
    patch panel_path("queue"), params: { width: 360 }

    assert_response :no_content
    assert_equal 360, @gaston.reload.width_of("queue")
  end

  # The hand was held inside the room, but a request is not a hand: anybody on
  # the LAN can send this app any number at all.
  test "a width nobody could have dragged is held at the end of its rope" do
    patch panel_path("queue"), params: { width: 9999 }

    assert_response :no_content
    assert_equal Panel::WIDEST, @gaston.reload.width_of("queue")
  end

  # A panel let go of in a room with no content in it was not given a width — 950
  # pixels is not a width a rail can hold, and this would refuse it. It was given a
  # share of the room, and the two are kept apart.
  test "a panel let go of in an empty room is a room divided" do
    patch panel_path("queue"), params: { share: 900 }

    assert_response :no_content
    assert_equal 900, @gaston.reload.share_of("queue")
    assert_equal Panel::BORN, @gaston.width_of("queue")
  end

  test "a share nobody could have dragged is held at the end of its rope" do
    patch panel_path("queue"), params: { share: 9_999_999 }

    assert_response :no_content
    assert_equal Panel::MOST_SHARE, @gaston.reload.share_of("queue")
  end

  test "a panel let go of at neither one thing nor the other says so" do
    patch panel_path("queue"), params: { share: "half-ish" }

    assert_response :bad_request
    assert_equal 0, @gaston.reload.panels.count
  end

  test "a panel this app does not have is not made by asking for it" do
    patch panel_path("larder"), params: { width: 300 }

    assert_response :bad_request
    assert_equal 0, @gaston.reload.panels.count
  end

  # A width that is not a number is not a width, and it is not a 500 either.
  test "a width that is not a width says so" do
    patch panel_path("queue"), params: { width: "wide-ish" }

    assert_response :bad_request
    assert_equal 0, @gaston.reload.panels.count
  end

  # Nobody is listening, so there is nobody to remember this for.
  test "a panel cannot be widened by nobody" do
    delete session_path

    patch panel_path("queue"), params: { width: 360 }

    assert_redirected_to profiles_path
  end
end
