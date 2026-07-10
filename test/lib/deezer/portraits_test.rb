require "test_helper"

module Deezer
  class PortraitsTest < ActiveSupport::TestCase
    setup { @artist = Artist.create!(name: "Almafuerte") }

    test "an exact name gets its photograph, credited to Deezer" do
      portrait = Portraits.new(Knows.new("Almafuerte", "http://pic/xl")).portrait_of(@artist)

      assert_equal "the bytes", portrait.bytes
      assert_equal "Photo from Deezer", portrait.credit
    end

    # Deezer answers a search with whatever is close; only the same name is the
    # same band. Almafuerte is not Aguafuertes.
    test "a name that only looks like ours is refused" do
      assert_nil Portraits.new(Knows.new("Aguafuertes", "http://pic/xl")).portrait_of(@artist)
    end

    test "an artist Deezer never heard of has no portrait" do
      assert_nil Portraits.new(Knows.new(nil, nil)).portrait_of(@artist)
    end

    # A band Deezer lists but has no photo of comes back with the silhouette
    # placeholder, whose URL names no artist between the slashes. Not a face.
    test "the silhouette placeholder is not a portrait" do
      placeholder = "https://cdn-images.dzcdn.net/images/artist//1000x1000-000000-80-0-0.jpg"

      assert_nil Portraits.new(Knows.new("Almafuerte", placeholder)).portrait_of(@artist)
    end

    private

    class Knows
      def initialize(name, picture)
        @name = name
        @picture = picture
      end

      def search(_query)
        return { "data" => [] } if @name.nil?

        { "data" => [ { "name" => @name, "picture_xl" => @picture } ] }
      end

      def download(_url) = "the bytes"
    end
  end
end
