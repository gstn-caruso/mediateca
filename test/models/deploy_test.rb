require "test_helper"

class DeployTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  # Every tab that is open is looking at the build that was live when it loaded.
  # A deploy that has gone live says so, once, to all of them at the same time.
  test "a deploy that went live tells every open tab" do
    assert_broadcasts Deploy::STREAM, 1 do
      Deploy.went_live
    end
  end

  # A refresh, not a reload: Turbo morphs the page onto the new build, and a
  # morph steps around anything permanent — which is where the <audio> lives.
  # This is what lets a deploy land without the music stopping to receive it.
  test "what it tells them is to refresh" do
    Deploy.went_live

    told = ActiveSupport::JSON.decode(broadcasts(Deploy::STREAM).sole)

    assert_equal %(<turbo-stream action="refresh"></turbo-stream>), told
  end
end
