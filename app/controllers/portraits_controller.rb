class PortraitsController < ApplicationController
  include ServesMedia

  def show
    artist = Artist.find(params[:artist_id])

    serve_picture artist.portrait_path, root: Rails.configuration.x.portraits_root
  end
end
