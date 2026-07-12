require "test_helper"

class ListeningForDeploysTest < ActionDispatch::IntegrationTest
  setup { listening_as }

  test "every page listens for a deploy going live" do
    get root_path

    assert_response :success
    assert_select "turbo-cable-stream-source[signed-stream-name]"
  end

  # A refresh that morphs, not one that reloads: morphing steps around the
  # permanent element the <audio> lives in, so the music does not stop for a
  # deploy. Reloading would throw the player away and rebuild it.
  test "a refresh morphs the page rather than rebuilding it" do
    get root_path

    assert_select "meta[name=turbo-refresh-method][content=morph]", count: 1
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]", count: 1
  end
end
