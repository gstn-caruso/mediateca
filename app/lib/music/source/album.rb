module Music
  module Source
    # An album as some source describes it — beets, or the filesystem itself.
    #
    # Its directory is its identity: two sources describing the same folder are
    # describing the same album, and that is what lets one enrich the other.
    Album = Data.define(:directory, :title, :artist, :year, :genre, :album_type, :disc_total, :cover_path, :tracks)
  end
end
