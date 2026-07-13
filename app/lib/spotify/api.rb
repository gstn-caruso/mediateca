require "net/http"

module Spotify
  # Spotify has the best photographs and the strictest terms: it asks that its
  # content not be stored or altered, and this app stores it and crops it round.
  # So it is asked only when somebody deliberately hands it credentials.
  class Api
    # Never got an answer, or got one nobody could act on. Worth trying again.
    Unreachable = Class.new(StandardError)

    # Answered, and the answer is no. Trying again changes nothing.
    Refused = Class.new(StandardError)

    # Asked to slow down. Worth trying again, later and slower.
    Busy = Class.new(StandardError)

    TOKEN_URL = "https://accounts.spotify.com/api/token".freeze
    SEARCH_URL = "https://api.spotify.com/v1/search".freeze
    AUTHORIZE_URL = "https://accounts.spotify.com/authorize".freeze
    API = "https://api.spotify.com/v1".freeze

    # Only what is needed to read what the listener kept: their songs, their
    # records, their lists. Nothing that could change any of it, and nothing about
    # anybody else.
    SCOPE = "user-library-read playlist-read-private playlist-read-collaborative".freeze

    # All Spotify hands over in one page of anything.
    PAGE = 50

    # Reading a listener's own library needs only the client id — PKCE is for
    # public clients, and its whole point is that there is no secret to keep on a
    # NAS. The portraits need the secret, and they are a different errand.
    def signed_in?
      Rails.configuration.x.spotify_client_id.present?
    end

    def configured?
      Rails.configuration.x.spotify_client_id.present? &&
        Rails.configuration.x.spotify_client_secret.present?
    end

    def search(name)
      uri = URI.parse(SEARCH_URL)
      uri.query = URI.encode_www_form(q: name, type: "artist", limit: 5)

      JSON.parse(get(uri, "Authorization" => "Bearer #{token}"))
    end

    def download(url) = get(URI.parse(url))

    # --- The listener's own Spotify --------------------------------------------
    #
    # PKCE: the app proves it is the same app that started the journey by showing,
    # at the end, the secret it hashed at the beginning. No client secret is
    # involved, which is exactly right for something running on a NAS.

    def authorize_url(returning_to:, verifier:, state:)
      "#{AUTHORIZE_URL}?#{URI.encode_www_form(
        client_id: Rails.configuration.x.spotify_client_id,
        response_type: 'code',
        redirect_uri: returning_to,
        code_challenge_method: 'S256',
        code_challenge: challenge_for(verifier),
        scope: SCOPE,
        state:
      )}"
    end

    def tokens_for(code:, verifier:, returning_to:)
      granted(
        grant_type: "authorization_code", code:, redirect_uri: returning_to,
        client_id: Rails.configuration.x.spotify_client_id, code_verifier: verifier
      )
    end

    # Spotify may hand back a new refresh token, and may not. Both are correct, and
    # a caller that overwrites the old one with nothing has disconnected itself.
    def refreshed(refresh_token)
      granted(
        grant_type: "refresh_token", refresh_token:,
        client_id: Rails.configuration.x.spotify_client_id
      )
    end

    def me(token:)
      said = ask("/me", token:)

      { username: said["display_name"].presence || said.fetch("id") }
    end

    # Every song the listener ever hearted. Fifty at a time, following the `next`
    # link Spotify itself hands back, which is the only page count it can be
    # trusted about.
    def saved_tracks(token:)
      through("/me/tracks?limit=#{PAGE}", token:).map { song_in(it["track"]) }
    end

    def saved_albums(token:)
      through("/me/albums?limit=#{PAGE}", token:).map do |kept|
        { artist: kept.dig("album", "artists", 0, "name"), title: kept.dig("album", "name") }
      end
    end

    def playlists(token:)
      through("/me/playlists?limit=#{PAGE}", token:).map { { id: it["id"], name: it["name"] } }
    end

    # `/items`, not `/tracks`. The older one is deprecated, and in the development
    # mode every self-hosted app is stuck in forever it does not merely warn — it
    # answers 403, for every list, and takes the import down with it.
    #
    # And it hands each line back under `item`, not `track` — which is the whole
    # reason for the rename: a line in a Spotify list can be a podcast episode, and
    # `item` is what a thing that might not be a song is called. Read it looking for
    # `track` and every list comes back empty, which is a lie a client tells
    # cheerfully and without any error at all.
    #
    # Both facts checked against the real Spotify: `/tracks` answers 403, `/items`
    # answers 200, and what is inside it is `item`.
    def playlist_songs(id, token:)
      through("/playlists/#{id}/items?limit=#{PAGE}", token:).filter_map do |line|
        song = line["item"]
        next unless song.is_a?(Hash) && song["type"] == "track" && song["name"].present?

        song_in(song)
      end
    end

    private

    # A local file or a podcast episode can sit in a playlist, and neither of them
    # is a song with an artist.
    def song_in(track)
      { artist: track.dig("artists", 0, "name"), track: track["name"] }
    end

    # PKCE's whole trick, in one line: the challenge is the hash of the verifier,
    # so whoever completes the journey must be whoever started it.
    def challenge_for(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end

    def granted(**form)
      response = Net::HTTP.post_form(URI.parse(TOKEN_URL), form)
      said = JSON.parse(response.body)

      raise Refused, "Spotify: #{said["error_description"] || said["error"]}" unless response.is_a?(Net::HTTPSuccess)

      { access_token: said.fetch("access_token"), refresh_token: said["refresh_token"], expires_in: said.fetch("expires_in") }
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "Spotify: #{e.message}"
    end

    # Not through `get`, which is the portraits' door and answers to a different
    # question. Here the status *is* the answer, and the answers differ in kind:
    #
    #   429 — "not so fast". Spotify says how long to wait, and waiting is the
    #         whole of the fix.
    #   5xx — "not right now". Worth trying again later.
    #   4xx — "no". Spotify will not hand over that list, and it is entitled not
    #         to. Asking again five times changes nothing and is how an API account
    #         gets suspended.
    #
    # Telling a 403 apart from a dead socket is not pedantry. Conflating them is
    # what turned one refused playlist into five retries of an entire import, and
    # then into an import that never finished at all.
    def ask(path, token:, patience: 1)
      uri = URI.parse(path.start_with?("http") ? path : "#{API}#{path}")
      answer = Net::HTTP.get_response(uri, "Authorization" => "Bearer #{token}")

      case answer
      when Net::HTTPSuccess then JSON.parse(answer.body)
      when Net::HTTPTooManyRequests then wait_out(answer, path, token:, patience:)
      when Net::HTTPServerError then raise Unreachable, "Spotify: #{uri.path} answered #{answer.code}"
      else raise Refused, "Spotify: #{uri.path} answered #{answer.code}"
      end
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "Spotify: #{e.message}"
    end

    # Spotify says how long to wait, and it means it. Once, though: a 429 that
    # survives being waited out is a rhythm this import cannot keep, and the job
    # that called it will come back later with a longer one.
    def wait_out(answer, path, token:, patience:)
      raise Busy, "Spotify: asked to slow down, and did, and it was not enough" if patience.zero?

      sleep [ answer["retry-after"].to_i, 1 ].max
      ask(path, token:, patience: patience - 1)
    end

    # Spotify pages by handing back the URL of the next page, and nothing else it
    # says about how many there are can be relied on.
    def through(path, token:)
      all = []

      while path
        said = ask(path, token:)
        all.concat(said.fetch("items"))
        path = said["next"]
      end

      all
    end

    # No user signs in: reading the catalogue is the client's own business.
    def token
      @token ||= begin
        response = Net::HTTP.post_form(URI.parse(TOKEN_URL), grant_type: "client_credentials",
                                                             client_id: Rails.configuration.x.spotify_client_id,
                                                             client_secret: Rails.configuration.x.spotify_client_secret)
        raise Unreachable, "Spotify refused the credentials: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body).fetch("access_token")
      end
    end

    def get(uri, headers = {})
      response = Net::HTTP.get_response(uri, headers)
      raise Unreachable, "#{uri} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "#{uri}: #{e.message}"
    end
  end
end
