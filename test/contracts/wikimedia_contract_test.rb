require "test_helper"

# The only test that talks to MusicBrainz, Wikidata and Commons.
#
# Everything else runs against the recordings in test/fixtures/wikimedia. What
# nothing else can verify is exactly what this verifies: that they still answer
# the way we recorded, and that the band we refuse is still a band they would
# have offered us.
#
# Skipped when they cannot be reached. REQUIRE_NETWORK turns the skip into a
# failure, so a green suite never means "we quietly checked nothing".
class WikimediaContractTest < ActiveSupport::TestCase
  setup do
    @api = Wikimedia::Api.new
    next if reachable?

    flunk "Wikimedia is unreachable and REQUIRE_NETWORK demands it" if ENV["REQUIRE_NETWORK"].present?

    skip "Wikimedia is unreachable"
  end

  test "MusicBrainz still knows an artist named exactly Almafuerte" do
    names = @api.search("Almafuerte").fetch("artists").map { |a| a["name"] }

    assert_includes names, "Almafuerte"
  end

  # The refusal test passes today because MusicBrainz offers a different band.
  # If it ever adds this one, that test would be passing for the wrong reason.
  test "MusicBrainz still has no artist named exactly Los Socios del Desierto" do
    names = @api.search("Los Socios del Desierto").fetch("artists").map { |a| a["name"].downcase }

    refute_includes names, "los socios del desierto"
  end

  # And the fallback tile is still what Hermética gets.
  test "Wikidata still holds no photograph of Hermética" do
    claims = @api.image("Q1605212")["claims"]

    assert(claims.blank? || !claims.key?("P18"))
  end

  private

  def reachable?
    @api.search("Almafuerte")
    true
  rescue StandardError
    false
  end
end
