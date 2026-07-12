# The genre was written on every scan and read by nobody. It was there for the
# album header, the header stopped showing it, and the column outlived the only
# thing that ever asked for it: the importer went on carrying a value from the
# tags all the way down into the table for no one to see.
#
# The catalog is derived data. Whatever the tags and beets still say about genre
# they will go on saying, and it is a scan away if a genre ever earns its place
# again.
class RemoveGenreFromAlbums < ActiveRecord::Migration[8.1]
  def change
    remove_column :albums, :genre, :string
  end
end
