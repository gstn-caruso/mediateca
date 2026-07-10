MUSIC_ROOT = "/mnt/data/multimedia/Música".freeze
GUANACO = "#{MUSIC_ROOT}/Almafuerte/1995 - Mundo guanaco".freeze

# Builders for the value objects a source hands to the importer, so the
# importer's tests describe the contract between them and never open a database.
module SourceBuilders
  # Anything that responds to #albums is a valid import source.
  Fake = Data.define(:albums)

  def source(albums: [])
    Fake.new(albums:)
  end

  def source_album(
    directory: GUANACO, title: "Mundo Guanaco", artist: "Almafuerte", year: 1995,
    genre: "", album_type: "album", disc_total: 1, cover_path: nil, tracks: []
  )
    Music::Source::Album.new(directory:, title:, artist:, year:, genre:, album_type:, disc_total:, cover_path:, tracks:)
  end

  def source_track(
    path: "#{GUANACO}/02 - Desencuentro.flac", title: "Desencuentro",
    track_no: 1, disc_no: 1, duration: 136.9, audio: nil
  )
    Music::Source::Track.new(path:, title:, track_no:, disc_no:, duration:, audio:)
  end
end
