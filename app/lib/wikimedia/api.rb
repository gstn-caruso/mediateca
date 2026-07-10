require "net/http"

module Wikimedia
  # The only object that knows MusicBrainz, Wikidata and Commons are on the
  # other side of a socket.
  class Api
    Unreachable = Class.new(StandardError)

    # MusicBrainz asks to be told who is calling, and to be called once a second.
    USER_AGENT = "Mediateca/1.0 (https://github.com/gstn-caruso/mediateca)".freeze
    ONE_SECOND = 1.1

    def search(name)
      musicbrainz("artist", query: %(artist:"#{name}"), fmt: "json", limit: 3)
    end

    def relations(mbid)
      musicbrainz("artist/#{mbid}", inc: "url-rels", fmt: "json")
    end

    def image(qid)
      json(Rails.configuration.x.wikidata_api, action: "wbgetclaims", entity: qid, property: "P18", format: "json")
    end

    def file(name)
      json(Rails.configuration.x.commons_api, action: "query", format: "json", prop: "imageinfo",
                                              iiprop: "url|extmetadata", iiurlwidth: 1000, titles: "File:#{name}")
    end

    def download(url) = get(URI.parse(url))

    private

    def musicbrainz(path, **params)
      throttle

      json("#{Rails.configuration.x.musicbrainz_api}/#{path}", **params)
    end

    def throttle
      waited = Time.now - (@last_call || Time.at(0))
      sleep(ONE_SECOND - waited) if waited < ONE_SECOND

      @last_call = Time.now
    end

    def json(base, **params)
      uri = URI.parse(base)
      uri.query = URI.encode_www_form(params)

      JSON.parse(get(uri))
    end

    def get(uri)
      response = Net::HTTP.get_response(uri, "User-Agent" => USER_AGENT)
      response = Net::HTTP.get_response(URI.parse(response["location"]), "User-Agent" => USER_AGENT) if response.is_a?(Net::HTTPRedirection)
      raise Unreachable, "#{uri} answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "#{uri}: #{e.message}"
    end
  end
end
