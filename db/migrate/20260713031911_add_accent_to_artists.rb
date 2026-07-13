class AddAccentToArtists < ActiveRecord::Migration[8.1]
  def change
    add_column :artists, :accent, :string
  end
end
