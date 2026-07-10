require "sqlite3"
require "tmpdir"

# Builds throwaway SQLite files shaped like a real beets library, so the tests
# never touch the NAS. Only the columns Beets::Library reads are declared.
#
# `path` and `artpath` are BLOBs in beets, holding raw filesystem bytes rather
# than text. The fixture writes them as blobs so the tests exercise the same
# decoding the real library does.
module BeetsFixture
  extend self

  SCHEMA = <<~SQL
    CREATE TABLE albums (
      id INTEGER PRIMARY KEY,
      artpath BLOB,
      albumartist TEXT,
      album TEXT,
      genre TEXT,
      year INTEGER,
      disctotal INTEGER,
      albumtype TEXT
    );
    CREATE TABLE items (
      id INTEGER PRIMARY KEY,
      path BLOB,
      album_id INTEGER,
      title TEXT,
      artist TEXT,
      track INTEGER,
      disc INTEGER,
      length REAL,
      bitrate INTEGER,
      format TEXT
    );
  SQL

  ALBUM_DEFAULTS = {
    artpath: nil, albumartist: "Almafuerte", album: "Mundo Guanaco",
    genre: "", year: 1995, disctotal: 1, albumtype: "album"
  }.freeze

  ITEM_DEFAULTS = {
    path: "/mnt/data/multimedia/Música/track.flac", album_id: 1,
    title: "Desencuentro", artist: "Almafuerte", track: 1, disc: 1,
    length: 136.9, bitrate: 1024323, format: "FLAC"
  }.freeze

  def build(albums: [], items: [])
    path = File.join(Dir.mktmpdir("beets-fixture"), "musiclibrary.db")

    SQLite3::Database.new(path) do |db|
      db.execute_batch(SCHEMA)
      albums.each { |album| insert(db, :albums, ALBUM_DEFAULTS.merge(album)) }
      items.each { |item| insert(db, :items, ITEM_DEFAULTS.merge(item)) }
    end

    path
  end

  def empty = build

  private

  def insert(db, table, row)
    columns = row.keys.join(", ")
    placeholders = ([ "?" ] * row.size).join(", ")
    db.execute("INSERT INTO #{table} (#{columns}) VALUES (#{placeholders})", row.values.map { as_blob(it) })
  end

  # Only the two path columns are blobs; everything else binds as-is.
  def as_blob(value)
    value.is_a?(String) && value.start_with?("/") ? SQLite3::Blob.new(value) : value
  end
end
