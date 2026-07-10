module Deezer
  # A music service knows a band by exactly the name on its records, so it is
  # asked before Wikimedia, whose name search wanders off to whoever is close
  # and hands an artist somebody else's face. Deezer's picture is a promo shot
  # with terms like Spotify's — not free to store — but on a private disk the
  # owner has already decided that is fine.
  class Portraits
    def initialize(api = Api.new)
      @api = api
    end

    def portrait_of(artist)
      found = artists(artist.name).find { |theirs| same_name?(theirs["name"], artist.name) }
      url = pictured(found) or return

      Portrait.new(bytes: @api.download(url), credit: "Photo from Deezer")
    end

    private

    def artists(name) = @api.search(name)["data"] || []

    # A band Deezer lists but has no photo of comes back with a silhouette whose
    # URL names no artist between the slashes: `.../images/artist//...`.
    def pictured(artist)
      url = artist&.dig("picture_xl")

      url if url.present? && !url.include?("/artist//")
    end

    def same_name?(theirs, ours) = theirs.to_s.strip.casecmp(ours.to_s.strip).zero?
  end
end
