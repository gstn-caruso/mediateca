class AddAccentToAlbums < ActiveRecord::Migration[8.1]
  def change
    add_column :albums, :accent, :string
  end
end
