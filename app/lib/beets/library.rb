require "sqlite3"

module Beets
  # Read-only gateway to a beets SQLite library.
  class Library
    ALBUMS = <<~SQL
      SELECT id, album, albumartist, year, genre, albumtype, disctotal, artpath
      FROM albums
    SQL

    TRACKS = <<~SQL
      SELECT album_id, id, title, track, disc, length, path
      FROM items
      ORDER BY album_id, disc, track
    SQL

    def initialize(database_path)
      @database_path = database_path.to_s
    end

    def albums
      read do |database|
        tracks = tracks_by_album(database)
        database.execute(ALBUMS).map { |row| album_from(row, tracks) }
      end
    end

    private

    def read
      database = SQLite3::Database.new(@database_path, readonly: true)
      yield database
    ensure
      database&.close
    end

    # One pass over the items table, so a library of any size costs two queries.
    def tracks_by_album(database)
      database.execute(TRACKS).group_by(&:first).transform_values do |rows|
        rows.map { |row| track_from(row) }
      end
    end

    def album_from(row, tracks)
      beets_id, title, artist, year, genre, album_type, disc_total, cover_path = row

      Music::Source::Album.new(
        beets_id:, title:, artist:, year:, genre:, album_type:,
        disc_total: disc_total || 1,
        cover_path: text(cover_path),
        tracks: tracks.fetch(beets_id, [])
      )
    end

    def track_from(row)
      _album_id, beets_id, title, track_no, disc_no, duration, path = row

      Music::Source::Track.new(beets_id:, title:, track_no:, duration:, disc_no: disc_no || 1, path: text(path))
    end

    # beets keeps filesystem paths as raw bytes in BLOB columns, so they arrive
    # tagged as binary. The bytes are already UTF-8; only the label is missing.
    def text(bytes)
      bytes&.dup&.force_encoding(Encoding::UTF_8)
    end
  end
end
