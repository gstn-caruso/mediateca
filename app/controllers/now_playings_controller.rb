# What is on right now, for Last.fm to say so while it is still on.
#
# A play is a different thing and arrives later: it is written down once the song
# has actually been listened to. This is told at the first note, and only by a
# listener who has a Last.fm — nobody else has anywhere to tell.
class NowPlayingsController < ApplicationController
  def create
    NowPlayingJob.perform_later(Current.profile, Track.find(params[:track_id])) if Current.profile.scrobbles?

    head :no_content
  end
end
