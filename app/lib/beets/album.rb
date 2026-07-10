module Beets
  # An album as beets knows it. Immutable; the importer translates it into ours.
  Album = Data.define(:beets_id, :title, :artist, :year, :genre, :album_type, :disc_total, :cover_path, :tracks)
end
