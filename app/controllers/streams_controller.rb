class StreamsController < ApplicationController
  include ServesMedia

  def show
    track = Track.find(params[:track_id])

    serve track.path, as: "audio/flac"
  end
end
