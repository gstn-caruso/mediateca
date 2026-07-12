require "test_helper"

module Beets
  class LibraryTest < ActiveSupport::TestCase
    GUANACO = "/mnt/data/multimedia/Música/Almafuerte/1995 - Mundo guanaco".freeze

    test "a library with no albums returns none" do
      library = Library.new(BeetsFixture.empty)

      assert_empty library.albums
    end

    test "reads an album's data" do
      library = Library.new(BeetsFixture.build(
        albums: [ {
          id: 7,
          album: "Del entorno",
          albumartist: "Almafuerte",
          year: 1996,
          disctotal: 1,
          albumtype: "album",
          artpath: "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/cover.jpg"
        } ],
        items: [ { album_id: 7, path: "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/01.flac" } ]
      ))

      album = library.albums.sole

      assert_equal "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno", album.directory
      assert_equal "Del entorno", album.title
      assert_equal "Almafuerte", album.artist
      assert_equal 1996, album.year
      assert_equal 1, album.disc_total
      assert_equal "album", album.album_type
      assert_equal "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/cover.jpg", album.cover_path
    end

    test "an album exposes its tracks" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1 } ],
        items: [ {
          album_id: 1,
          title: "Desencuentro",
          track: 2,
          disc: 1,
          length: 136.9,
          path: "#{GUANACO}/02 - Desencuentro.flac"
        } ]
      ))

      track = library.albums.sole.tracks.sole

      assert_equal "Desencuentro", track.title
      assert_equal 2, track.track_no
      assert_equal 1, track.disc_no
      assert_in_delta 136.9, track.duration
      assert_equal "#{GUANACO}/02 - Desencuentro.flac", track.path
    end

    # The album's directory is its identity, and it's the only thing beets and
    # the filesystem can agree on without knowing each other.
    test "the album's directory is that of its tracks" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1 } ],
        items: [ { album_id: 1, path: "#{GUANACO}/01.flac" }, { album_id: 1, path: "#{GUANACO}/02.flac" } ]
      ))

      assert_equal GUANACO, library.albums.sole.directory
    end

    # Green Day's Warning deluxe has its tracks in CD01, CD02 and CD03. The
    # album's directory is the one they share, not any single one of them.
    test "an album split across subfolders by disc lives in the folder they share" do
      warning = "/mnt/data/multimedia/Música/Green Day/2025 - Warning (25th Anniversary Deluxe Edition)"
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, disctotal: 3 } ],
        items: [
          { album_id: 1, disc: 1, path: "#{warning}/CD01/01.flac" },
          { album_id: 1, disc: 2, path: "#{warning}/CD02/01.flac" },
          { album_id: 1, disc: 3, path: "#{warning}/CD03/01.flac" }
        ]
      ))

      assert_equal warning, library.albums.sole.directory
    end

    # beets keeps albums whose files no longer exist — the 6 System of a Down
    # ones, for example. With no tracks there's no directory and nothing to play.
    test "an album with no tracks isn't reported" do
      library = Library.new(BeetsFixture.build(albums: [ { id: 1 } ]))

      assert_empty library.albums
    end

    test "a multi-disc album's tracks are ordered by disc and number" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, disctotal: 2 } ],
        items: [
          { album_id: 1, disc: 2, track: 1, path: "#{GUANACO}/d2t1.flac" },
          { album_id: 1, disc: 1, track: 1, path: "#{GUANACO}/d1t1.flac" },
          { album_id: 1, disc: 1, track: 2, path: "#{GUANACO}/d1t2.flac" }
        ]
      ))

      album = library.albums.sole

      assert_equal 2, album.disc_total
      assert_equal [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ] ], album.tracks.map { |track| [ track.disc_no, track.track_no ] }
    end

    # beets stores paths as raw bytes in BLOB columns. The NAS has accents
    # ("Música") and Cyrillic ("Ленинград"); if they're read without re-tagging
    # the encoding, they arrive as binary and match nothing.
    test "paths come out of the BLOB as readable UTF-8" do
      leningrad = "/mnt/data/multimedia/Música/Кино/1982 - Ленинград"
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, artpath: "#{leningrad}/cover.jpg" } ],
        items: [ { album_id: 1, path: "#{leningrad}/01 - Бездельник.flac" } ]
      ))

      album = library.albums.sole

      assert_equal Encoding::UTF_8, album.cover_path.encoding
      assert_equal leningrad, album.directory
      assert_equal "#{leningrad}/01 - Бездельник.flac", album.tracks.sole.path
      assert_equal Encoding::UTF_8, album.tracks.sole.path.encoding
    end

    test "an album with no cover exposes it as nil" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, artpath: nil } ],
        items: [ { album_id: 1 } ]
      ))

      assert_nil library.albums.sole.cover_path
    end
  end
end
