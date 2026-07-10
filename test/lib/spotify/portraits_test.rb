require "test_helper"

module Spotify
  class PortraitsTest < ActiveSupport::TestCase
    setup { @artist = Artist.create!(name: "Almafuerte") }

    # Nobody handed it credentials, so it holds its tongue rather than raising.
    test "without credentials it is not asked, and does not answer" do
      assert_nil Portraits.new(Unconfigured.new).portrait_of(@artist)
    end

    test "with credentials, an exact name gets its photograph" do
      portrait = Portraits.new(Knows.new("Almafuerte")).portrait_of(@artist)

      assert_equal "the bytes", portrait.bytes
      assert_equal "Photo from Spotify", portrait.credit
    end

    test "a name that only looks like ours is refused" do
      assert_nil Portraits.new(Knows.new("Almafuerte Tributo")).portrait_of(@artist)
    end

    private

    class Unconfigured
      def configured? = false
    end

    class Knows
      def initialize(name) = @name = name
      def configured? = true
      def search(_query) = { "artists" => { "items" => [ { "name" => @name, "images" => [ { "url" => "http://pic" } ] } ] } }
      def download(_url) = "the bytes"
    end
  end
end
