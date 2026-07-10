# Builders for the value objects Beets::Library hands to the importer, so the
# importer's tests describe the contract between them and never open a database.
module BeetsBuilders
  # Anything that responds to #albums is a valid import source.
  Source = Data.define(:albums)

  def source(albums: [])
    Source.new(albums:)
  end

  def beets_album(
    beets_id: 1, title: "Mundo Guanaco", artist: "Almafuerte", year: 1995,
    genre: "", album_type: "album", disc_total: 1, cover_path: nil, tracks: []
  )
    Beets::Album.new(beets_id:, title:, artist:, year:, genre:, album_type:, disc_total:, cover_path:, tracks:)
  end

  def beets_track(
    beets_id: 1, title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
    path: "/mnt/data/multimedia/Música/Almafuerte/1995 - Mundo guanaco/02 - Desencuentro.flac"
  )
    Beets::Track.new(beets_id:, title:, track_no:, disc_no:, duration:, path:)
  end
end
