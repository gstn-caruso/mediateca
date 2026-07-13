# Everything a listener has heard and not yet told Last.fm about.
#
# It runs off the request, because a listener pressing play should never wait on
# a website, and it retries — because the machine this runs on is a NAS in
# somebody's house, and the internet it needs is not the internet it always has.
# Last.fm will take a scrobble late.
class ScrobbleJob < ApplicationJob
  queue_as :default

  # The only two refusals Last.fm asks us to try again on, and a line that was
  # simply down. Retrying anything else is how an API account gets suspended.
  retry_on Lastfm::Api::Unreachable, Lastfm::Api::Busy, wait: :polynomially_longer, attempts: 10

  def perform(profile)
    profile.scrobbler&.send_what_is_waiting
  end
end
