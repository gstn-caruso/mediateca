class ArtistsController < ApplicationController
  include ServesMedia

  def index
    @artists = Artist.ordered.includes(:albums)
    @recently_played = Current.profile.recently_played_albums
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.ordered
  end

  def portrait
    artist = Artist.find(params[:id])

    serve artist.portrait_path, as: image_type(artist.portrait_path),
                                root: Rails.configuration.x.portraits_root
  end

  private

  def image_type(path)
    Rack::Mime.mime_type(File.extname(path.to_s), "image/jpeg")
  end
end
