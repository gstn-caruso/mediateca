require "test_helper"

module Beets
  class LibraryTest < ActiveSupport::TestCase
    GUANACO = "/mnt/data/multimedia/Música/Almafuerte/1995 - Mundo guanaco".freeze

    test "una biblioteca sin álbumes no devuelve ninguno" do
      library = Library.new(BeetsFixture.empty)

      assert_empty library.albums
    end

    test "lee los datos de un álbum" do
      library = Library.new(BeetsFixture.build(
        albums: [ {
          id: 7,
          album: "Del entorno",
          albumartist: "Almafuerte",
          year: 1996,
          genre: "",
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

    test "un álbum expone sus tracks" do
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

    # El directorio del álbum es su identidad, y es lo único que beets y el
    # filesystem pueden acordar sin conocerse.
    test "el directorio del álbum es el de sus tracks" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1 } ],
        items: [ { album_id: 1, path: "#{GUANACO}/01.flac" }, { album_id: 1, path: "#{GUANACO}/02.flac" } ]
      ))

      assert_equal GUANACO, library.albums.sole.directory
    end

    # El Warning deluxe de Green Day tiene sus tracks en CD01, CD02 y CD03. El
    # directorio del álbum es el que comparten, no el de ninguno de ellos.
    test "un álbum repartido en subcarpetas por disco vive en la carpeta que comparten" do
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

    # beets guarda álbumes cuyos archivos ya no existen —los 6 de System of a
    # Down, por ejemplo. Sin tracks no hay directorio ni nada que sonar.
    test "un álbum sin tracks no se reporta" do
      library = Library.new(BeetsFixture.build(albums: [ { id: 1 } ]))

      assert_empty library.albums
    end

    test "los tracks de un álbum multi-disco van ordenados por disco y número" do
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

    # beets guarda los paths como bytes crudos en columnas BLOB. En el NAS hay
    # acentos ("Música") y cirílico ("Ленинград"); si se leen sin re-etiquetar
    # el encoding, llegan como binario y no matchean nada.
    test "los paths salen del BLOB como UTF-8 legible" do
      leningrado = "/mnt/data/multimedia/Música/Кино/1982 - Ленинград"
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, artpath: "#{leningrado}/cover.jpg" } ],
        items: [ { album_id: 1, path: "#{leningrado}/01 - Бездельник.flac" } ]
      ))

      album = library.albums.sole

      assert_equal Encoding::UTF_8, album.cover_path.encoding
      assert_equal leningrado, album.directory
      assert_equal "#{leningrado}/01 - Бездельник.flac", album.tracks.sole.path
      assert_equal Encoding::UTF_8, album.tracks.sole.path.encoding
    end

    # 23 de los 75 álbumes del NAS tienen genre = '' (string vacío), no NULL.
    test "un género vacío se preserva como string vacío" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, genre: "" } ],
        items: [ { album_id: 1 } ]
      ))

      assert_equal "", library.albums.sole.genre
    end

    test "un álbum sin carátula la expone como nil" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, artpath: nil } ],
        items: [ { album_id: 1 } ]
      ))

      assert_nil library.albums.sole.cover_path
    end
  end
end
