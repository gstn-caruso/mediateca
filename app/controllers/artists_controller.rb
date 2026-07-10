class ArtistsController < ApplicationController
  def index
    @artists = Artist.ordered.includes(:albums)
    @recently_played = Current.profile.recently_played_albums
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.ordered
  end
end
