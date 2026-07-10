module Wikimedia
  # Wikimedia Commons cannot hold an album sleeve: a sleeve is somebody's
  # copyright. So a picture found here is a photograph of a person and never the
  # cover of a record — which is the whole reason for asking here, rather than
  # somewhere with better coverage that hands out sleeves.
  #
  # MusicBrainz answers a name search with whatever is close, and close is how an
  # artist ends up wearing somebody else's face. Only the same name is the same
  # artist.
  class Portraits
    def initialize(api = Api.new)
      @api = api
    end

    def portrait_of(artist)
      mbid = exact_mbid(artist.name) or return
      qid = wikidata_id(mbid) or return
      file = picture(qid) or return

      described(file)
    end

    private

    def exact_mbid(name)
      found = @api.search(name).fetch("artists", []).find { |artist| same_name?(artist["name"], name) }

      found && found["id"]
    end

    def wikidata_id(mbid)
      relation = @api.relations(mbid).fetch("relations", []).find { |r| r["type"] == "wikidata" }

      relation&.dig("url", "resource")&.split("/")&.last
    end

    # Wikidata knows plenty of bands it has no picture of. That is an answer.
    def picture(qid)
      claims = @api.image(qid)["claims"]
      return unless claims.is_a?(Hash)

      claims.dig("P18", 0, "mainsnak", "datavalue", "value")
    end

    def described(file)
      info = @api.file(file).dig("query", "pages").values.first.fetch("imageinfo").first

      Portrait.new(bytes: @api.download(info.fetch("thumburl")), credit: credit(info.fetch("extmetadata")))
    end

    # CC BY-SA asks for the photographer's name. The answer arrives as a link.
    def credit(metadata)
      author = plain(metadata.dig("Artist", "value"))
      licence = plain(metadata.dig("LicenseShortName", "value"))

      [ author.presence, licence.presence, "via Wikimedia Commons" ].compact.join(", ")
    end

    def plain(html) = CGI.unescapeHTML(html.to_s.gsub(/<[^>]*>/, "")).strip

    def same_name?(theirs, ours) = theirs.to_s.strip.casecmp(ours.to_s.strip).zero?
  end
end
