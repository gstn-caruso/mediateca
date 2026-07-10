class CreatePlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :playlists do |t|
      t.references :profile, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    # Two people may each keep a playlist called Rock; one person may not keep
    # two.
    add_index :playlists, [ :profile_id, :name ], unique: true

    create_table :playlist_entries do |t|
      t.references :playlist, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end

    add_index :playlist_entries, [ :playlist_id, :position ]
  end
end
