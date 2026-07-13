# The rail asks this when it runs out of queue, and queues whatever it answers.
# So the answer is spelled the way the player writes a track down: the same keys
# a row carries in its dataset, ready to be pushed onto the queue as it stands.
class SuggestionsController < ApplicationController
  def show
    track = Track.find(params[:track_id])
    suggestions = Suggestions.new(track:, profile: Current.profile, queued: params[:queued].to_s.split(","))

    render json: { heading: suggestions.heading, tracks: suggestions.tracks.map { queueable(it) } }
  end

  private

  def queueable(track)
    {
      trackId: track.id,
      src: helpers.stream_url(track),
      title: track.title,
      subtitle: track.artist_name,
      cover: helpers.cover_url(track.album),
      album: album_path(track.album),
      albumTitle: track.album.title
    }
  end
end
