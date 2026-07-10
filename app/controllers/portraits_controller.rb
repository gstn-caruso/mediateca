class PortraitsController < ApplicationController
  include ServesMedia

  def show
    artist = Artist.find(params[:artist_id])

    serve artist.portrait_path, as: image_type(artist.portrait_path),
                                root: Rails.configuration.x.portraits_root
  end

  private

  def image_type(path)
    Rack::Mime.mime_type(File.extname(path.to_s), "image/jpeg")
  end
end
