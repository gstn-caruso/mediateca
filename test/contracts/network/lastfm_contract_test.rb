require "test_helper"

# The only test that talks to Last.fm.
#
# Everything else in the suite runs against a fake that answers the way we believe
# Last.fm answers. This is the one that asks Last.fm whether that belief is still
# true — and there is a lot of belief here, because a great deal of what everybody
# "knows" about this API is not in its documentation at all.
#
# It needs an API account: without LASTFM_API_KEY it skips, and REQUIRE_NETWORK
# turns the skip into a failure, so a green suite never means "we quietly checked
# nothing".
#
# Nothing here is signed with a listener's session key and nothing here writes:
# a contract test must not scrobble to somebody's real account.
class LastfmContractTest < ActiveSupport::TestCase
  def self.api = @api ||= Lastfm::Api.new

  setup do
    skip "no Last.fm API account (LASTFM_API_KEY)" unless self.class.api.configured? || require_network?
    flunk "REQUIRE_NETWORK is set and there is no Last.fm API account" unless self.class.api.configured?
  end

  # The endpoint answers JSON at all, over HTTPS — which is worth pinning, because
  # Last.fm's own documentation writes every URL as plain http.
  test "Last.fm still answers over HTTPS, and in JSON" do
    said = ask(method: "artist.getSimilar", artist: "Almafuerte", limit: 3)

    assert said.key?("similarartists"), "Last.fm answered: #{said.inspect}"
  end

  # The similarity score the recommendations lean on, and its shape: a string
  # holding a number between 0 and 1.
  test "similar artists still come back with a match between nought and one" do
    similar = ask(method: "artist.getSimilar", artist: "Almafuerte", limit: 3)
                .dig("similarartists", "artist")

    assert_predicate similar, :any?
    assert_includes 0.0..1.0, similar.first.fetch("match").to_f
    assert similar.first.fetch("name").present?
  end

  # An error arrives inside a 200 OK, in a body with an "error" key. Everything in
  # Api leans on this, and it is the thing that would break most quietly.
  test "Last.fm still says no inside a perfectly successful response" do
    said = ask(method: "artist.getSimilar")

    assert said.key?("error"), "expected a refusal, got: #{said.inspect}"
    assert said.key?("message")
  end

  # The unauthenticated reads the import is built on. A user who has never existed
  # is a refusal (code 6), which is exactly how we would find out a name is wrong.
  test "a listener nobody has heard of is refused, and by number" do
    said = ask(method: "user.getRecentTracks", user: "mediateca-nobody-at-all-#{SecureRandom.hex(6)}")

    assert_equal 6, said["error"]
  end

  private

  # Deliberately not through Api: this is the test that checks Api's beliefs, so
  # it does its own asking and reads the raw answer.
  def ask(**params)
    uri = URI.parse(Lastfm::Api::ENDPOINT)
    uri.query = URI.encode_www_form(params.merge(api_key: Rails.configuration.x.lastfm_api_key, format: "json"))

    JSON.parse(Net::HTTP.get_response(uri, "User-Agent" => Lastfm::Api::AGENT).body)
  end

  def require_network? = ENV["REQUIRE_NETWORK"].present?
end
