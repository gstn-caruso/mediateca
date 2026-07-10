class CreateTracks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracks do |t|
      t.integer :beets_id, null: false
      t.string :title, null: false
      t.integer :track_no
      t.integer :disc_no, null: false, default: 1
      t.float :duration
      t.string :path, null: false
      t.references :album, null: false, foreign_key: true

      t.timestamps
    end

    add_index :tracks, :beets_id, unique: true
    add_index :tracks, :path, unique: true
    add_index :tracks, [ :album_id, :disc_no, :track_no ]
  end
end
