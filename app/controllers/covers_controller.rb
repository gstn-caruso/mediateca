class CoversController < ApplicationController
  include ServesMedia

  def show
    album = Album.find(params[:album_id])

    serve album.cover_path, as: cover_type(album.cover_path)
  end

  private

  def cover_type(path)
    Rack::Mime.mime_type(File.extname(path.to_s), "image/jpeg")
  end
end
