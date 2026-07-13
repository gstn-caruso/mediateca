# One place the app reaches for the torrent client, so one place a test can answer
# instead. The same bargain Lastfm and Spotify strike, for the same reason: there
# is no mocking library here, and no test may touch the network.
module Qbittorrent
  class << self
    attr_writer :api

    def api
      @api ||= Api.new
    end
  end
end
