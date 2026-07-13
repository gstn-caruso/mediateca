# Everything in the app that talks to Last.fm comes here for the line, and this is
# the only place an Api is ever built.
#
# That is what lets a test answer in Last.fm's place. There is no mocking library
# here and no test may touch the network: a fake is handed over, and it is the
# same one object the whole app would have used.
module Lastfm
  class << self
    attr_writer :api

    def api
      @api ||= Api.new
    end
  end
end
