# What pressing play on a thing queues, when the press did not happen on that
# thing's own page.
#
# The queue has always been filled from the song rows on the screen, which is
# exactly what a rail, a shelf and an artist's header do not have. So whatever was
# pressed is asked for its songs, and it answers in the player's own words — the
# same words a row carries in its dataset, so the queue is one queue however it
# came to be filled.
class QueuesController < ApplicationController
  def show
    render json: { tracks: pressed.songs.map { |track| helpers.queued(track) } }
  end

  private

  # A record, or the person who made it. Both know what they put on; neither is
  # asked how.
  def pressed
    return Album.find(params[:album_id]) if params[:album_id]

    Artist.find(params[:artist_id])
  end
end
