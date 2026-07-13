# Connecting a Last.fm means the listening this library already has to offer it —
# the year you spent here before you ever mentioned Last.fm to it.
#
# It queues the lot and then sends it, which is one job doing two things on
# purpose: the queue has to be full before anything starts draining it, or the
# history goes out in two halves and out of order.
class CatchUpOnLastfmJob < ApplicationJob
  queue_as :default

  def perform(profile)
    return unless profile.scrobbles?

    profile.scrobbler.catch_up_on_the_history
    ScrobbleJob.perform_later(profile)
  end
end
