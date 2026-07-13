class StreamsController < ApplicationController
  include ServesMedia

  def show
    track = Track.find(params[:track_id])

    serve track.path, as: Music::Format.content_type(track.path)
  end
end
