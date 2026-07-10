class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.integer :beets_id, null: false
      t.string :title, null: false
      t.integer :year
      t.string :genre
      t.string :album_type
      t.integer :disc_total, null: false, default: 1
      t.string :cover_path
      t.references :artist, null: false, foreign_key: true

      t.timestamps
    end

    add_index :albums, :beets_id, unique: true
  end
end
