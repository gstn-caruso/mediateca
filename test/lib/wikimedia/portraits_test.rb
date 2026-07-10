require "test_helper"

module Wikimedia
  class PortraitsTest < ActiveSupport::TestCase
    setup { @almafuerte = Artist.create!(name: "Almafuerte") }

    test "an artist with a photograph on Commons gets it, and its credit" do
      portrait = Portraits.new(Recorded.new).portrait_of(@almafuerte)

      assert_equal "the bytes", portrait.bytes
      assert_equal "Braiansib, CC BY-SA 3.0, via Wikimedia Commons", portrait.credit
    end

    # MusicBrainz answers with whatever is close. Spinetta y los Socios del
    # Desierto is a different band from Los Socios del Desierto.
    test "a band that only looks like the one we asked for is refused" do
      socios = Artist.create!(name: "Los Socios del Desierto")

      assert_nil Portraits.new(Recorded.new).portrait_of(socios)
    end

    # Wikidata knows the band and holds no picture of it. That is an answer.
    test "an artist Wikidata has no picture of has no portrait" do
      hermetica = Artist.create!(name: "Hermética")

      assert_nil Portraits.new(Recorded.new).portrait_of(hermetica)
    end

    test "an artist MusicBrainz never heard of has no portrait" do
      assert_nil Portraits.new(Recorded.new).portrait_of(Artist.create!(name: "Nobody At All"))
    end

    private

    # Replays what MusicBrainz, Wikidata and Commons really answered.
    class Recorded
      def search(name)
        case name
        when "Almafuerte" then recording("almafuerte-search")
        when "Los Socios del Desierto" then recording("socios-search")
        when "Hermética" then { "artists" => [ { "id" => "herm-mbid", "name" => "Hermética" } ] }
        else { "artists" => [] }
        end
      end

      def relations(mbid)
        return recording("almafuerte-relations") unless mbid == "herm-mbid"

        { "relations" => [ { "type" => "wikidata", "url" => { "resource" => "https://www.wikidata.org/wiki/Q1605212" } } ] }
      end

      def image(qid) = recording(qid == "Q950768" ? "almafuerte-claims" : "hermetica-claims")
      def file(_name) = recording("commons-almafuerte")
      def download(_url) = "the bytes"

      private

      def recording(name)
        JSON.parse(Rails.root.join("test/fixtures/wikimedia/#{name}.json").read)
      end
    end
  end
end
