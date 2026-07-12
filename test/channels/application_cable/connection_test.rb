require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  # The socket a deploy is announced on. Without a connection class there is no
  # socket at all — and the page would not let on, because the markup that
  # subscribes renders just the same either way.
  test "a tab can open the socket a deploy is announced on" do
    connect

    assert_kind_of ApplicationCable::Connection, connection
  end
end
