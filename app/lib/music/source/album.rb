module Music
  module Source
    # An album as some source describes it — beets today, the filesystem next.
    # Immutable; the importer translates it into ours.
    Album = Data.define(:beets_id, :title, :artist, :year, :genre, :album_type, :disc_total, :cover_path, :tracks)
  end
end
