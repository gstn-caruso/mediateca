require "net/http"

module Spotify
  # Spotify has the best photographs and the strictest terms: it asks that its
  # content not be stored or altered, and this app stores it and crops it round.
  # So it is asked only when somebody deliberately hands it credentials.
  class Api
    Unreachable = Class.new(StandardError)

    TOKEN_URL = "https://accounts.spotify.com/api/token".freeze
    SEARCH_URL = "https://api.spotify.com/v1/search".freeze

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

    private

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
