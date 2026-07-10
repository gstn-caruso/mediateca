module Music
  # Mirrors a music source into our catalog. The source is anything that answers
  # #albums with Music::Source::Album values.
  #
  # Importing is idempotent: a directory identifies an album and a path
  # identifies a track, so re-running against an unchanged source is a no-op and
  # a changed one updates in place.
  class Importer
    def import(source)
      albums = source.albums

      ApplicationRecord.transaction do
        albums.each { |album| import_album(album) }
        discard_vanished_albums(albums)
        discard_artists_without_albums
      end
    end

    private

    # An empty source and an unmounted NAS look exactly alike, and only one of
    # them means the music is gone.
    def discard_vanished_albums(albums)
      return if albums.empty?

      Album.where.not(directory: albums.map(&:directory)).destroy_all
    end

    def discard_artists_without_albums
      Artist.where.missing(:albums).destroy_all
    end

    def import_album(album)
      record = Album.find_or_initialize_by(directory: album.directory)
      record.update!(
        title: album.title,
        year: album.year,
        genre: album.genre,
        album_type: album.album_type,
        disc_total: album.disc_total,
        cover_path: album.cover_path,
        artist: artist_named(album.artist)
      )

      album.tracks.each { |track| import_track(track, record) }
      discard_vanished_tracks(record, album)
    end

    def import_track(track, album)
      record = Track.find_or_initialize_by(path: track.path)
      record.update!(
        title: track.title,
        track_no: track.track_no,
        disc_no: track.disc_no,
        duration: track.duration,
        album: album
      )
    end

    # A track renamed on disk arrives as a new path, and the old one is gone.
    # Left alone, the album would collect ghosts that cannot be played.
    def discard_vanished_tracks(record, album)
      record.tracks.where.not(path: album.tracks.map(&:path)).destroy_all
    end

    def artist_named(name)
      Artist.find_or_create_by!(name: name)
    end
  end
end
