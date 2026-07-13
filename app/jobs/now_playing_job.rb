# What is on right now, told to Last.fm as the song starts rather than when it
# counts: it is what puts the song on a listener's Last.fm page while it is still
# playing.
#
# Last.fm is explicit that these are never to be retried, and it is right: a
# now-playing is a claim about this minute, and by the time a retry landed it
# would be a lie. So a Last.fm that is down or unfriendly simply means nobody on
# the internet sees the song — and the scrobble, which is the part that lasts,
# goes through the queue that does survive.
class NowPlayingJob < ApplicationJob
  queue_as :default

  discard_on Lastfm::Api::Unreachable, Lastfm::Api::Refused

  def perform(profile, track)
    profile.scrobbler&.now_playing(track)
  end
end
