class TracksController < ApplicationController
  include ServesMedia

  def stream
    track = Track.find(params[:id])

    serve track.path, as: "audio/flac"
  end
end
