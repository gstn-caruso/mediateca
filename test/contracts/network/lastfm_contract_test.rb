require "test_helper"

# The only test that talks to Last.fm.
#
# Everything else in the suite runs against a fake that answers the way we believe
# Last.fm answers. This is the one that asks Last.fm whether the belief is true —
# and there is a lot of belief here, because much of what everybody "knows" about
# this API is not in its documentation at all.
#
# The first two need no API account: they pin the thing the whole client rests on,
# and they can be run by anybody. The rest need a key, and skip without one.
# REQUIRE_NETWORK turns that skip into a failure, so a green suite never means
# "we quietly checked nothing".
#
# Nothing here is signed with a listener's session key and nothing here writes: a
# contract test must never scrobble to somebody's real account.
class LastfmContractTest < ActiveSupport::TestCase
  def self.api = @api ||= Lastfm::Api.new

  # The belief the whole client rests on, and the one that would break most
  # quietly. Last.fm refuses under an honest 403 for a bad key, and — per its own
  # documentation — under a 200 for a scrobble it silently threw away. So Api
  # never reads the status and always reads the body. If Last.fm ever stopped
  # putting `error` in the body, this client would start believing every refusal.
  test "a refusal is in the body, whatever the envelope says" do
    refused = ask(method: "artist.getSimilar", artist: "Almafuerte", api_key: "deadbeefdeadbeefdeadbeefdeadbeef")

    assert_equal 10, said(refused)["error"], "expected 'Invalid API key'"
    assert said(refused).key?("message")
    assert_not refused.is_a?(Net::HTTPSuccess), "a bad key answers 4xx — and a client that read the status would still have to read the body anyway"
  end

  # A write is a POST, and Last.fm says so by refusing anything else.
  test "a scrobble asked for over GET is refused for being a GET" do
    refused = ask(method: "track.scrobble", api_key: "deadbeefdeadbeefdeadbeefdeadbeef")

    assert_equal 4, said(refused)["error"]
    assert_match(/POST/i, said(refused)["message"])
  end

  # Worth pinning because Last.fm's own documentation writes every URL as plain
  # http — and this app will not send a listener's session key over one. Getting
  # any answer at all is the proof: the request went over TLS to reach it.
  test "Last.fm still answers over HTTPS, and in JSON when asked" do
    assert_match "https://", Lastfm::Api::ENDPOINT

    answer = ask(method: "artist.getInfo", artist: "Almafuerte", api_key: "deadbeefdeadbeefdeadbeefdeadbeef")

    assert_nothing_raised { said(answer) }
    assert_match "json", answer["content-type"].to_s
  end

  # From here on, a real key is needed.
  test "similar artists still come back with a match between nought and one" do
    with_a_key do
      similar = answered(method: "artist.getSimilar", artist: "Almafuerte", limit: 3).dig("similarartists", "artist")

      assert_predicate similar, :any?
      assert_includes 0.0..1.0, similar.first.fetch("match").to_f
      assert similar.first.fetch("name").present?
    end
  end

  # The unauthenticated read the import is built on. A listener who never existed
  # is refused by number, which is exactly how a wrong name would announce itself.
  test "a listener nobody has heard of is refused, and by number" do
    with_a_key do
      said = answered(method: "user.getRecentTracks", user: "mediateca-nobody-#{SecureRandom.hex(6)}")

      assert_equal 6, said["error"]
    end
  end

  private

  def with_a_key
    skip "no Last.fm API account (LASTFM_API_KEY)" unless self.class.api.configured? || ENV["REQUIRE_NETWORK"].present?
    flunk "REQUIRE_NETWORK is set and there is no Last.fm API account" unless self.class.api.configured?

    yield
  end

  # Deliberately not through Api: this is the test of Api's beliefs, so it does
  # its own asking and reads the raw answer.
  def ask(**params)
    uri = URI.parse(Lastfm::Api::ENDPOINT)
    uri.query = URI.encode_www_form(params.reverse_merge(format: "json"))

    Net::HTTP.get_response(uri, "User-Agent" => Lastfm::Api::AGENT)
  end

  def answered(**params)
    said(ask(**params.merge(api_key: Rails.configuration.x.lastfm_api_key)))
  end

  def said(response) = JSON.parse(response.body)
end
