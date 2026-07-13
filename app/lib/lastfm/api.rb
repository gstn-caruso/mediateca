require "net/http"

module Lastfm
  # Last.fm's web service.
  #
  # Two things about it shape everything here.
  #
  # The first: the HTTP status is never the answer. Sometimes it is honest — a 403
  # for a bad API key, a 400 for a bad parameter — and sometimes it is a 200 that
  # means no, which is how it reports a scrobble it silently threw away. Last.fm
  # says so itself: "No matter what the HTTP status code is, you must inspect the
  # content of the response." So the status is never read and the body always is.
  #
  # The second: it is explicit about which refusals are worth trying again. Two of
  # them, and no others. Retrying the rest is how an API account gets suspended.
  class Api
    # Never got an answer at all. The NAS lost its uplink, or Last.fm did.
    Unreachable = Class.new(StandardError)

    # It answered, and the answer is no.
    Refused = Class.new(StandardError)

    # The listener took the privilege back on Last.fm's own settings page. There
    # is nothing to retry: the session is over until they connect again.
    Revoked = Class.new(Refused)

    # Last.fm is having a moment. The only refusals it asks us to try again on.
    Busy = Class.new(Refused)

    ENDPOINT = "https://ws.audioscrobbler.com/2.0/".freeze

    # Where the listener goes to say yes.
    AUTHORIZE = "https://www.last.fm/api/auth/".freeze

    # Last.fm asks for a user agent it can recognise, and warns that not having
    # one is a way to get the account suspended.
    AGENT = "Mediateca (+https://github.com/gstn-caruso/mediateca)".freeze

    REVOKED = 9
    BUSY = [ 11, 16 ].freeze

    def configured?
      key.present? && secret.present?
    end

    # Last.fm sends the listener back here with a token on the query string. The
    # token is good for an hour and good for exactly one use.
    def authorize_url(returning_to:)
      "#{AUTHORIZE}?#{URI.encode_www_form(api_key: key, cb: returning_to)}"
    end

    # The token is spent here. What comes back is a session key with no expiry at
    # all: Last.fm holds it until the listener revokes it.
    def session_for(token)
      said = signed_get("auth.getSession", token:).fetch("session")

      { username: said.fetch("name"), session_key: said.fetch("key") }
    end

    # What is on right now. Not retried if it fails, and not worth much if it is:
    # it is a claim about this minute.
    def now_playing(song, as:)
      signed_post("track.updateNowPlaying", **song, sk: as)
    end

    # Up to fifty songs in one call, each parameter numbered. Last.fm answers with
    # what it did with each — and "threw it away" is one of the answers it gives
    # inside a perfectly successful response.
    def scrobble(songs, as:)
      ignored_codes(signed_post("track.scrobble", **numbered(songs), sk: as))
    end

    private

    # artist[0], track[0], timestamp[0], artist[1]… The signature sorts these by
    # the ASCII table, which is why Signature does too.
    def numbered(songs)
      songs.each_with_index.flat_map { |song, at|
        song.map { |name, value| [ "#{name}[#{at}]", value ] }
      }.to_h
    end

    # One song comes back as an object and fifty come back as an array — Last.fm's
    # JSON does that everywhere, and it is the classic way to crash on the first
    # song somebody plays.
    def ignored_codes(said)
      Array.wrap(said.dig("scrobbles", "scrobble")).map { it.dig("ignoredMessage", "code").to_i }
    end

    def key = Rails.configuration.x.lastfm_api_key
    def secret = Rails.configuration.x.lastfm_api_secret

    def signed_get(method, **params)
      answered(fetch(uri_for(signed(method, **params))))
    end

    # Every write is a POST with the parameters in the body, urlencoded and UTF-8.
    # Last.fm says so, and a scrobble is a write.
    def signed_post(method, **params)
      answered(post(signed(method, **params)))
    end

    def post(params)
      uri = URI.parse(ENDPOINT)
      asking = Net::HTTP::Post.new(uri, "User-Agent" => AGENT)
      asking.set_form_data(params)

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { it.request(asking) }
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Unreachable, "Last.fm: #{e.message}"
    end

    # Every call carries the API key; a signed one also carries the proof that we
    # hold the shared secret. `format` is asked for after signing, because it is
    # one of the two parameters Last.fm does not sign.
    def signed(method, **params)
      called = params.merge(method:, api_key: key)

      called.merge(api_sig: Signature.new(secret).for(called), format: "json")
    end

    def uri_for(params)
      URI.parse(ENDPOINT).tap { it.query = URI.encode_www_form(params) }
    end

    def fetch(uri)
      Net::HTTP.get_response(uri, "User-Agent" => AGENT)
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Unreachable, "Last.fm: #{e.message}"
    end

    # The status is not the answer, so it is not read. A refusal arrives as JSON
    # with an `error` in it — sometimes under an honest 403, sometimes under a 200
    # — and what that error says is what decides whether trying again could ever
    # help. A body that is not JSON at all means nobody who speaks for Last.fm was
    # at the other end: a captive portal, a proxy, a NAS with no uplink.
    def answered(response)
      said = JSON.parse(response.body)
      raise refusal_of(said["error"]), "Last.fm: #{said["message"]} (#{said["error"]})" if said.key?("error")

      said
    rescue JSON::ParserError
      raise Unreachable, "Last.fm answered #{response.code}, and not in JSON"
    end

    def refusal_of(code)
      return Revoked if code == REVOKED
      return Busy if BUSY.include?(code)

      Refused
    end
  end
end
