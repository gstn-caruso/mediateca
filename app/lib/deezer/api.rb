require "net/http"

module Deezer
  # Deezer answers a name search over an open API — no key, no token, no sign-in.
  # It is only reached across a socket, and a socket can be down; that is the one
  # thing this object knows.
  class Api
    Unreachable = Class.new(StandardError)

    SEARCH_URL = "https://api.deezer.com/search/artist".freeze

    def search(name)
      uri = URI.parse(SEARCH_URL)
      uri.query = URI.encode_www_form(q: name, limit: 5)

      JSON.parse(get(uri))
    end

    def download(url) = get(URI.parse(url))

    private

    def get(uri)
      response = Net::HTTP.get_response(uri)
      response = Net::HTTP.get_response(URI.parse(response["location"])) if response.is_a?(Net::HTTPRedirection)
      raise Unreachable, "#{uri} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "#{uri}: #{e.message}"
    end
  end
end
