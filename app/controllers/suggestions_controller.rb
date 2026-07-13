# The rail asks this when it runs out of queue, and queues whatever it answers.
# So the answer is spelled the way the player writes a track down — which is said
# in one place now, and said the same way to everybody who has to fill a queue.
#
# It used to be spelled here too, and a word was missing: the palette. A song
# suggested by the rail played in whatever colour the last one left behind, which
# is the one thing this app promises never to do.
class SuggestionsController < ApplicationController
  def show
    track = Track.find(params[:track_id])
    suggestions = Suggestions.new(track:, profile: Current.profile, queued: params[:queued].to_s.split(","))

    render json: { heading: suggestions.heading, tracks: suggestions.tracks.map { helpers.queued(it) } }
  end
end
