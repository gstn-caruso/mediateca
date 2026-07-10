module Spotify
  # Asked last, and only when credentials were given on purpose. Spotify's terms
  # ask that its pictures not be stored or altered; this app does both, so the
  # owner of the NAS decides, not the code.
  class Portraits
    def initialize(api = Api.new)
      @api = api
    end

    def portrait_of(artist)
      return unless @api.configured?

      found = artists(artist.name).find { |theirs| same_name?(theirs["name"], artist.name) }
      url = found&.dig("images", 0, "url") or return

      Portrait.new(bytes: @api.download(url), credit: "Photo from Spotify")
    end

    private

    def artists(name) = @api.search(name).dig("artists", "items") || []

    def same_name?(theirs, ours) = theirs.to_s.strip.casecmp(ours.to_s.strip).zero?
  end
end
