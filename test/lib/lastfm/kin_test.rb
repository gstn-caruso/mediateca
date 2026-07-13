require "test_helper"

module Lastfm
  class KinTest < ActiveSupport::TestCase
    setup do
      Lastfm.api = @lastfm = FakeSimilar.new
      @almafuerte = Artist.create!(name: "Almafuerte")
      @hermetica = Artist.create!(name: "Hermética")
    end

    test "a band Last.fm calls kin, and this house owns, is written down" do
      @lastfm.says("Almafuerte" => [ { name: "Hermética", match: 0.9 } ])

      Kin.new(pause: 0).find_for(@almafuerte)

      assert_equal @hermetica, Kinship.sole.kin
      assert_in_delta 0.9, Kinship.sole.match
    end

    # The whole design. Last.fm will name a hundred bands like Almafuerte and the
    # rail can play exactly none of them — so only the ones on this disk are kept.
    test "a band this house owns nothing by is not kin, however alike Last.fm says" do
      @lastfm.says("Almafuerte" => [ { name: "Some Band We Do Not Own", match: 0.99 } ])

      Kin.new(pause: 0).find_for(@almafuerte)

      assert_predicate Kinship.all, :empty?
    end

    # Last.fm writes "Hermetica" as often as anybody writes "Hermética".
    test "accents are nothing, here as everywhere" do
      @lastfm.says("Almafuerte" => [ { name: "HERMETICA", match: 0.8 } ])

      Kin.new(pause: 0).find_for(@almafuerte)

      assert_equal @hermetica, Kinship.sole.kin
    end

    # Below this Last.fm is reaching, and a rail full of reaching is a rail nobody
    # trusts.
    test "a band Last.fm is only reaching for is not kin" do
      @lastfm.says("Almafuerte" => [ { name: "Hermética", match: 0.01 } ])

      Kin.new(pause: 0).find_for(@almafuerte)

      assert_predicate Kinship.all, :empty?
    end

    test "asking again refreshes what Last.fm thinks rather than collecting opinions" do
      @lastfm.says("Almafuerte" => [ { name: "Hermética", match: 0.9 } ])
      Kin.new(pause: 0).find_for(@almafuerte)

      @lastfm.says("Almafuerte" => [ { name: "Hermética", match: 0.5 } ])
      Kin.new(pause: 0).find_for(@almafuerte)

      assert_equal 1, Kinship.count
      assert_in_delta 0.5, Kinship.sole.match
    end

    # A NAS with no uplink still has a library. The rail falls back to the draw it
    # has always had, and the next sweep asks again.
    test "a Last.fm nobody can reach leaves the library exactly as it was" do
      Lastfm.api = FakeLastfm::Unreachable.new.tap do
        it.define_singleton_method(:similar_artists) { |*, **| raise Api::Unreachable, "no route to host" }
      end

      assert_nothing_raised { Kin.new(pause: 0).find_for(@almafuerte) }
      assert_predicate Kinship.all, :empty?
    end

    # Last.fm, asked who is like whom.
    class FakeSimilar < FakeLastfm
      def says(bands)
        @bands = bands
        self
      end

      def similar_artists(name, limit: 100)
        @bands.fetch(name, [])
      end
    end
  end
end
