# El catálogo es dato derivado: se reconstruye entero con un `rails music:import`.
# Por eso las tablas se rehacen en vez de migrarse — un backfill de `directory`
# a partir del primer track daría mal en el álbum de Green Day, cuyos tracks
# viven en CD01/CD02/CD03 y no en el directorio del álbum.
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
      # El directorio es la identidad del álbum: es lo único que beets y el
      # filesystem pueden acordar sin conocerse.
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
