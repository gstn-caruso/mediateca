require "test_helper"

module Music
  class FirstPortraitTest < ActiveSupport::TestCase
    setup { @artist = Artist.create!(name: "Almafuerte") }

    # What you put on the disk beats what a stranger's server thinks.
    test "the first source that has a face wins" do
      chain = FirstPortrait.new(Has.new("from disk"), Has.new("from the web"))

      assert_equal "from disk", chain.portrait_of(@artist).bytes
    end

    test "a source with nothing steps aside" do
      chain = FirstPortrait.new(Empty.new, Has.new("from the web"))

      assert_equal "from the web", chain.portrait_of(@artist).bytes
    end

    # A NAS that lost its uplink still has its disk.
    test "a source that cannot be reached steps aside rather than ending the search" do
      chain = FirstPortrait.new(Broken.new, Has.new("from disk"))

      assert_equal "from disk", chain.portrait_of(@artist).bytes
    end

    test "nobody has a face for this one" do
      assert_nil FirstPortrait.new(Empty.new, Empty.new).portrait_of(@artist)
    end

    private

    class Has
      def initialize(bytes) = @bytes = bytes
      def portrait_of(_artist) = Portrait.new(bytes: @bytes, credit: nil)
    end

    class Empty
      def portrait_of(_artist) = nil
    end

    class Broken
      def portrait_of(_artist) = raise(Wikimedia::Api::Unreachable, "no route to host")
    end
  end
end
