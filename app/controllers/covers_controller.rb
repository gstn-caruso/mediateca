class CoversController < ApplicationController
  include ServesMedia

  def show
    album = Album.find(params[:album_id])

    serve_picture album.cover_path
  end
end
