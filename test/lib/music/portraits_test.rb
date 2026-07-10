require "test_helper"
require "tmpdir"

module Music
  class PortraitsTest < ActiveSupport::TestCase
    setup do
      @root = Dir.mktmpdir
      @almafuerte = Artist.create!(name: "Almafuerte")
    end

    teardown { FileUtils.remove_entry(@root) }

    test "an artist with no picture gets one, written where the music cannot be" do
      collect(source: Knows.new("Almafuerte" => "jpeg bytes"))

      path = @almafuerte.reload.portrait_path
      assert path.start_with?(@root), "the portrait must not land beside the records"
      assert_equal "jpeg bytes", File.binread(path)
    end

    # CC BY-SA asks for the photographer's name, so it is kept with the picture.
    test "what we owe for the picture is kept beside it" do
      collect(source: Knows.new("Almafuerte" => "jpeg bytes"), credit: "Braiansib, CC BY-SA 3.0")

      assert_equal "Braiansib, CC BY-SA 3.0", @almafuerte.reload.portrait_credit
    end

    # The bytes say what they are; a PNG served as a JPEG is a broken image.
    test "a PNG is written as a PNG" do
      collect(source: Knows.new("Almafuerte" => "\x89PNG and then some"))

      assert @almafuerte.reload.portrait_path.end_with?(".png")
    end

    test "an artist Deezer never heard of keeps no portrait, and no file" do
      collect(source: Knows.new({}))

      assert_nil @almafuerte.reload.portrait_path
      assert_empty Dir.children(@root)
    end

    # Deezer is asked once. A second run must not ask again.
    test "an artist who already has a portrait is not asked for again" do
      asked = Counting.new("Almafuerte" => "jpeg bytes")

      collect(source: asked)
      collect(source: asked)

      assert_equal 1, asked.asked
    end

    test "two artists sharing a picture share one file on disk" do
      Artist.create!(name: "Hermética")

      collect(source: Knows.new("Almafuerte" => "same bytes", "Hermética" => "same bytes"))

      assert_equal 1, Dir.children(@root).size
    end

    private

    def collect(source:, credit: nil)
      source.credit = credit if credit
      Portraits.new(source:, root: @root).collect
    end

    class Knows
      attr_accessor :credit

      def initialize(pictures) = @pictures = pictures

      def portrait_of(artist)
        bytes = @pictures[artist.name] or return

        Portrait.new(bytes:, credit: @credit)
      end
    end

    class Counting < Knows
      attr_reader :asked

      def initialize(pictures)
        super
        @asked = 0
      end

      def portrait_of(artist)
        @asked += 1
        super
      end
    end
  end
end
