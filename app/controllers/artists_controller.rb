class ArtistsController < ApplicationController
  # The library this page shows is the library in the rail beside it, and the
  # rail is already holding it — asked for a second time here, it was the same
  # question, answered twice on the one page that asks it twice.
  def index
    @recently_played = Current.profile.recently_played_albums
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.ordered
  end
end
