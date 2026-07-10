class AddPortraitToArtists < ActiveRecord::Migration[8.1]
  def change
    # Nobody photographs an artist onto a NAS. The picture is fetched once and
    # kept under storage/, so the path is not inside the media root.
    add_column :artists, :portrait_path, :string
  end
end
