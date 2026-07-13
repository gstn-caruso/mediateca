# The player says when a track started, and waits until the song is half over to
# say it. The stream endpoint could not do either: preload asks for the file
# before anybody presses play, and every seek asks again.
class PlaysController < ApplicationController
  def create
    Current.profile.played(Track.find(params[:track_id]), at: started_at)

    head :no_content
  end

  private

  # The player is the only one who was there when the music started, so the start
  # time travels with the news rather than being guessed from its arrival.
  #
  # The clock it read is the browser's, and a browser's clock can be wrong. A
  # song cannot have started after it was heard, so a time in the future is taken
  # to be now — and so is anything that is not a time at all.
  def started_at
    seconds = Integer(params[:started_at], exception: false)
    return Time.current unless seconds&.positive?

    [ Time.zone.at(seconds), Time.current ].min
  end
end
