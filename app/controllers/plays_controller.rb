# The player says when a track started. The stream endpoint could not: preload
# asks for the file before anybody presses play, and every seek asks again.
class PlaysController < ApplicationController
  def create
    Current.profile.played(Track.find(params[:track_id]))

    head :no_content
  end
end
