# Everything Last.fm has been keeping for this listener, brought home.
#
# It is the long way round and it is the direction that works: Last.fm hands over
# a whole history, back to the day the account was opened, and no session key is
# needed to ask. A hundred and twenty-seven thousand scrobbles is six hundred and
# thirty-seven pages, asked for one a second so nobody's account gets suspended —
# a quarter of an hour, off the request, with nothing waiting on it.
class ImportFromLastfmJob < ApplicationJob
  queue_as :default

  retry_on Lastfm::Api::Unreachable, Lastfm::Api::Busy, wait: :polynomially_longer, attempts: 5

  def perform(profile)
    return unless profile.scrobbles?

    Lastfm::Import.new(profile).bring_it_all_home
  end
end
