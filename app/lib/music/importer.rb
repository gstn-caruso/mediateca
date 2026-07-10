module Music
  # Mirrors an external music source into our catalog. The source is anything
  # that answers #albums with Music::Source::Album values.
  #
  # Importing is idempotent: beets ids are the identity, so re-running against
  # an unchanged source is a no-op and a changed one updates in place.
  class Importer
    def import(source)
      ApplicationRecord.transaction do
        source.albums.each { |album| import_album(album) }
      end
    end

    private

    def import_album(album)
      record = Album.find_or_initialize_by(beets_id: album.beets_id)
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
    end

    def import_track(track, album)
      record = Track.find_or_initialize_by(beets_id: track.beets_id)
      record.update!(
        title: track.title,
        track_no: track.track_no,
        disc_no: track.disc_no,
        duration: track.duration,
        path: track.path,
        album: album
      )
    end

    def artist_named(name)
      Artist.find_or_create_by!(name: name)
    end
  end
end
