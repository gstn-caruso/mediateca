class AlbumsController < ApplicationController
  def show
    @album = Album.includes(:artist, :tracks).find(params[:id])
  end
end
