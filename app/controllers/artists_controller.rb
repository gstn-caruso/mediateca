class ArtistsController < ApplicationController
  def index
    @artists = Artist.ordered.includes(:albums)
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.ordered
  end
end
