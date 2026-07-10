require "sqlite3"

module Beets
  # Read-only gateway to a beets SQLite library.
  class Library
    ALBUMS = <<~SQL
      SELECT id, album, albumartist, year, genre, albumtype, disctotal, artpath
      FROM albums
    SQL

    TRACKS = <<~SQL
      SELECT album_id, title, track, disc, length, path
      FROM items
      ORDER BY album_id, disc, track
    SQL

    def initialize(database_path)
      @database_path = database_path.to_s
    end

    def albums
      read do |database|
        tracks = tracks_by_album(database)

        database.execute(ALBUMS).filter_map { |row| album_from(row, tracks) }
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

    # An album beets knows but whose files it lost has nothing to identify it by
    # and nothing to play. beets keeps such rows; we do not.
    def album_from(row, tracks_by_album)
      beets_id, title, artist, year, genre, album_type, disc_total, cover_path = row
      tracks = tracks_by_album.fetch(beets_id, [])
      return if tracks.empty?

      Music::Source::Album.new(
        directory: directory_of(tracks),
        title:, artist:, year:, genre:, album_type:,
        disc_total: disc_total || 1,
        cover_path: text(cover_path),
        tracks: tracks
      )
    end

    def track_from(row)
      _album_id, title, track_no, disc_no, duration, path = row

      Music::Source::Track.new(title:, track_no:, duration:, disc_no: disc_no || 1, path: text(path))
    end

    # Most albums are one folder. Green Day's deluxe Warning splits its tracks
    # across CD01, CD02 and CD03, so the album's folder is the one they share.
    def directory_of(tracks)
      folders = tracks.map { |track| ::File.dirname(track.path) }.uniq
      return folders.sole if folders.one?

      common_ancestor(folders)
    end

    def common_ancestor(folders)
      trails = folders.map { |folder| folder.split("/") }
      shared = trails.first.take_while.with_index { |step, depth| trails.all? { |trail| trail[depth] == step } }

      shared.join("/")
    end

    # beets keeps filesystem paths as raw bytes in BLOB columns, so they arrive
    # tagged as binary. The bytes are already UTF-8; only the label is missing.
    def text(bytes)
      bytes&.dup&.force_encoding(Encoding::UTF_8)
    end
  end
end
