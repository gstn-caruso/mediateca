# Last.fm, without Last.fm.
#
# It is handed to the app exactly where the real Api would be, so the app cannot
# tell the difference — and it writes down what it was told instead of telling
# anybody. No test in this suite touches the network.
class FakeLastfm
  attr_reader :spent

  def initialize(configured: true, username: "gaston", session_key: "s3ss10nk3y")
    @configured = configured
    @username = username
    @session_key = session_key
    @spent = []
  end

  def configured?
    @configured
  end

  def authorize_url(returning_to:)
    "https://www.last.fm/api/auth/?#{URI.encode_www_form(api_key: "fake", cb: returning_to)}"
  end

  # A token is good for one use and one hour. Ours is good unless the test says
  # it is a token Last.fm will not take.
  def session_for(token)
    @spent << token
    raise Lastfm::Api::Refused, "Last.fm: Invalid authentication token (4)" if token == "no"

    { username: @username, session_key: @session_key }
  end

  # For the tests that need the line to be down rather than merely unfriendly.
  class Unreachable < FakeLastfm
    def session_for(_token)
      raise Lastfm::Api::Unreachable, "Last.fm: no route to host"
    end
  end
end
