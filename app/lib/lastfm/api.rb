require "net/http"

module Lastfm
  # Last.fm's web service.
  #
  # Two things about it shape everything here. It answers 200 OK and then says no
  # in the body, so a status code only proves it was asked — the body is what is
  # read. And it is explicit about which refusals are worth trying again: two of
  # them, and no others. Retrying the rest is how an application gets banned.
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

    private

    def key = Rails.configuration.x.lastfm_api_key
    def secret = Rails.configuration.x.lastfm_api_secret

    def signed_get(method, **params)
      answered(fetch(uri_for(signed(method, **params))))
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

    # A 200 is not a yes: Last.fm says no inside a perfectly successful response.
    # So the body is always read, and what it says decides whether trying again
    # could ever help.
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
