# The catalog is derived data: it gets rebuilt whole with `rails music:import`.
# That's why the tables are recreated instead of migrated — backfilling
# `directory` from the first track would get it wrong for the Green Day
# album, whose tracks live in CD01/CD02/CD03 and not in the album's
# directory.
class RekeyCatalogByPath < ActiveRecord::Migration[8.1]
  def change
    drop_table :tracks, force: :cascade
    drop_table :albums, force: :cascade
    drop_table :artists, force: :cascade

    create_table :artists do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :artists, :name, unique: true

    create_table :albums do |t|
      # The directory is the album's identity: it's the only thing beets and
      # the filesystem can agree on without knowing each other.
      t.string :directory, null: false
      t.string :title, null: false
      t.integer :year
      t.string :genre
      t.string :album_type
      t.integer :disc_total, null: false, default: 1
      t.string :cover_path
      t.references :artist, null: false, foreign_key: true

      t.timestamps
    end
    add_index :albums, :directory, unique: true

    create_table :tracks do |t|
      t.string :path, null: false
      t.string :title, null: false
      t.integer :track_no
      t.integer :disc_no, null: false, default: 1
      t.float :duration
      t.references :album, null: false, foreign_key: true

      t.timestamps
    end
    add_index :tracks, :path, unique: true
    add_index :tracks, [ :album_id, :disc_no, :track_no ]
  end
end
