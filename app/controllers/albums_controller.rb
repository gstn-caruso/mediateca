class AlbumsController < ApplicationController
  include ServesMedia

  def show
    @album = Album.includes(:artist, :tracks).find(params[:id])
  end

  def cover
    album = Album.find(params[:id])

    serve album.cover_path, as: cover_type(album.cover_path)
  end

  private

  def cover_type(path)
    Rack::Mime.mime_type(File.extname(path.to_s), "image/jpeg")
  end
end
