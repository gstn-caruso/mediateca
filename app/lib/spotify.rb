# Everything in the app that talks to Spotify comes here for the line, and this is
# the only place an Api is ever built — the same bargain Lastfm strikes, for the
# same reason: there is no mocking library here, and no test may touch the network.
module Spotify
  class << self
    attr_writer :api

    def api
      @api ||= Api.new
    end
  end
end
