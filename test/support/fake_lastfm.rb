# Last.fm, without Last.fm.
#
# It is handed to the app exactly where the real Api would be, so the app cannot
# tell the difference — and it writes down what it was told instead of telling
# anybody. No test in this suite touches the network.
class FakeLastfm
  attr_reader :spent, :scrobbled, :announced, :loved, :unloved

  # `ignoring` is what Last.fm says it did with each scrobble: 0 is "took it",
  # and 3 is "that is too far in the past" — which it says inside a 200 OK, and
  # which is the one that quietly eats a backfill.
  def initialize(configured: true, username: "gaston", session_key: "s3ss10nk3y", ignoring: 0)
    @configured = configured
    @username = username
    @session_key = session_key
    @ignoring = ignoring
    @spent = []
    @scrobbled = []
    @announced = []
    @loved = []
    @unloved = []
  end

  def configured?
    @configured
  end

  def authorize_url(returning_to:)
    "https://www.last.fm/api/auth/?#{URI.encode_www_form(api_key: "fake", cb: returning_to)}"
  end

  # A token is good for one hour and one use. Ours is good unless the test says
  # it is a token Last.fm will not take.
  def session_for(token)
    @spent << token
    raise Lastfm::Api::Refused, "Last.fm: Invalid authentication token (4)" if token == "no"

    { username: @username, session_key: @session_key }
  end

  def scrobble(songs, as:)
    @scrobbled.concat(songs)

    songs.map { @ignoring }
  end

  def now_playing(song, as:)
    @announced << song
  end

  def love(song, as:)
    @loved << song
  end

  def unlove(song, as:)
    @unloved << song
  end

  # The line is down: the NAS lost its uplink, or Last.fm did. Worth trying again.
  class Unreachable < FakeLastfm
    def session_for(*, **) = no_route
    def scrobble(*, **) = no_route
    def now_playing(*, **) = no_route
    def love(*, **) = no_route
    def unlove(*, **) = no_route

    private

    def no_route
      raise Lastfm::Api::Unreachable, "Last.fm: no route to host"
    end
  end

  # Last.fm is having a moment. One of exactly two refusals it asks us to retry.
  class Busy < FakeLastfm
    def scrobble(*, **)
      raise Lastfm::Api::Busy, "Last.fm: Service Offline (11)"
    end
  end

  # The listener took the privilege back on Last.fm's own settings page. There is
  # nothing to retry, and the session is over until they connect again.
  class Revoked < FakeLastfm
    def scrobble(*, **)
      raise Lastfm::Api::Revoked, "Last.fm: Invalid session key - Please re-authenticate (9)"
    end
  end
end
