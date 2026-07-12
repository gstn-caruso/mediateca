module Music
  # Mirrors a music source into our catalog. The source is anything that answers
  # #albums with Music::Source::Album values.
  #
  # Importing is idempotent: a directory identifies an album and a path
  # identifies a track, so re-running against an unchanged source is a no-op and
  # a changed one updates in place.
  #
  # But where a thing sits is a weak name for it, and the listener's own things —
  # playlists, hearts, everything ever played — hang off these rows. Rename a
  # file and the path it was known by is gone; left alone, the scan would greet
  # the same song as a stranger and destroy the row a playlist was holding. So
  # before anything is discarded, whatever merely moved is recognised and
  # followed (Music::Move).
  class Importer
    def import(source)
      albums = source.albums

      ApplicationRecord.transaction do
        follow_moved_albums(albums)
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

      vanished_albums(albums).destroy_all
    end

    def discard_artists_without_albums
      Artist.where.missing(:albums).destroy_all
    end

    # The rows the source no longer accounts for, and the albums we have never
    # seen: between them is whatever moved.
    def vanished_albums(albums)
      Album.where.not(directory: albums.map(&:directory))
    end

    def unknown_albums(albums)
      albums.reject { |album| Album.exists?(directory: album.directory) }
    end

    def vanished_tracks(record, album)
      record.tracks.where.not(path: album.tracks.map(&:path))
    end

    def unknown_tracks(album)
      album.tracks.reject { |track| Track.exists?(path: track.path) }
    end

    # A folder renamed is the same record in a new place. Recognised by what the
    # record is — whose it is, and what it is called — it keeps its row, and with
    # it every heart on it and every song inside.
    def follow_moved_albums(albums)
      Move.new(
        gone: vanished_albums(albums).map { |record| [ [ record.artist.name, record.title ], record ] },
        arrived: unknown_albums(albums).map { |album| [ [ album.artist, album.title ], album ] }
      ).each { |record, album| record.update!(directory: album.directory) }
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

      follow_moved_tracks(record, album)
      album.tracks.each { |track| import_track(track, record) }
      discard_vanished_tracks(record, album)
    end

    # A file renamed is the same song in a new place. Recognised by where it sits
    # on the record and what it is called, it keeps its row — and the playlists,
    # hearts and history hanging off it.
    def follow_moved_tracks(record, album)
      Move.new(
        gone: vanished_tracks(record, album).map { |row| [ song_of(row), row ] },
        arrived: unknown_tracks(album).map { |track| [ song_of(track), track ] }
      ).each { |row, track| row.update!(path: track.path) }
    end

    # What a song is, said without saying where its file lives.
    def song_of(track)
      [ track.disc_no, track.track_no, track.title ]
    end

    def import_track(track, album)
      record = Track.find_or_initialize_by(path: track.path)
      record.update!(
        title: track.title,
        artist: credit_of(track, album),
        track_no: track.track_no,
        disc_no: track.disc_no,
        duration: track.duration,
        album: album,
        codec: track.audio&.codec,
        bit_depth: track.audio&.bit_depth,
        sample_rate: track.audio&.sample_rate,
        bit_rate: track.audio&.bit_rate
      )
    end

    # The record already says who it is by, and 933 of the 934 songs say nothing
    # else. A song carries a credit of its own only when the file disagrees with
    # the sleeve — a guest, a duet, a compilation.
    def credit_of(track, album)
      track.artist if track.artist.present? && track.artist != album.artist.name
    end

    # Whatever did not merely move is really gone. Left alone, the album would
    # collect ghosts that cannot be played.
    def discard_vanished_tracks(record, album)
      vanished_tracks(record, album).destroy_all
    end

    def artist_named(name)
      Artist.find_or_create_by!(name: name)
    end
  end
end
