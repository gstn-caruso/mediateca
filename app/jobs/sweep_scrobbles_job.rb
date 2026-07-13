# Comes back for whatever is still waiting.
#
# ScrobbleJob retries, but a job's retries run out after some hours, and a NAS
# whose uplink is out for a whole weekend outlasts them. The songs are still in
# the queue and still perfectly good — Last.fm takes them late — so something has
# to come back for them, and keep coming back. This does, every half hour, for
# every listener with anything left to say.
class SweepScrobblesJob < ApplicationJob
  queue_as :default

  def perform
    Profile.where(id: Scrobble.waiting.select(:profile_id)).find_each do |profile|
      ScrobbleJob.perform_later(profile) if profile.scrobbles?
    end
  end
end
