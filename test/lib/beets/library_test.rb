require "test_helper"

module Beets
  class LibraryTest < ActiveSupport::TestCase
    test "una biblioteca sin álbumes no devuelve ninguno" do
      library = Library.new(BeetsFixture.empty)

      assert_empty library.albums
    end

    test "lee los datos de un álbum" do
      library = Library.new(BeetsFixture.build(albums: [ {
        id: 7,
        album: "Del entorno",
        albumartist: "Almafuerte",
        year: 1996,
        genre: "",
        disctotal: 1,
        albumtype: "album",
        artpath: "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/cover.jpg"
      } ]))

      album = library.albums.sole

      assert_equal 7, album.beets_id
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
          id: 10,
          album_id: 1,
          title: "Desencuentro",
          track: 2,
          disc: 1,
          length: 136.9,
          path: "/mnt/data/multimedia/Música/Almafuerte/1995 - Mundo guanaco/02 - Desencuentro.flac"
        } ]
      ))

      track = library.albums.sole.tracks.sole

      assert_equal 10, track.beets_id
      assert_equal "Desencuentro", track.title
      assert_equal 2, track.track_no
      assert_equal 1, track.disc_no
      assert_in_delta 136.9, track.duration
      assert_equal "/mnt/data/multimedia/Música/Almafuerte/1995 - Mundo guanaco/02 - Desencuentro.flac", track.path
    end

    test "un álbum sin tracks los expone como una lista vacía" do
      library = Library.new(BeetsFixture.build(albums: [ { id: 1 } ]))

      assert_empty library.albums.sole.tracks
    end

    test "los tracks de un álbum multi-disco van ordenados por disco y número" do
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, disctotal: 2 } ],
        items: [
          { id: 30, album_id: 1, disc: 2, track: 1, title: "primera del disco dos" },
          { id: 10, album_id: 1, disc: 1, track: 1, title: "primera del disco uno" },
          { id: 20, album_id: 1, disc: 1, track: 2, title: "segunda del disco uno" }
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
      cyrillic = "/mnt/data/multimedia/Música/Кино/1982 - Ленинград/01 - Бездельник.flac"
      library = Library.new(BeetsFixture.build(
        albums: [ { id: 1, artpath: "/mnt/data/multimedia/Música/Кино/1982 - Ленинград/cover.jpg" } ],
        items: [ { id: 10, album_id: 1, path: cyrillic } ]
      ))

      album = library.albums.sole

      assert_equal Encoding::UTF_8, album.cover_path.encoding
      assert_equal cyrillic, album.tracks.sole.path
      assert_equal Encoding::UTF_8, album.tracks.sole.path.encoding
    end

    # 23 de los 75 álbumes del NAS tienen genre = '' (string vacío), no NULL.
    test "un género vacío se preserva como string vacío" do
      library = Library.new(BeetsFixture.build(albums: [ { id: 1, genre: "" } ]))

      assert_equal "", library.albums.sole.genre
    end

    # 3 de los 75 álbumes apuntan a covers que ya no están en disco. La
    # biblioteca reporta lo que beets dice; validar la existencia es de otro.
    test "un álbum sin carátula la expone como nil" do
      library = Library.new(BeetsFixture.build(albums: [ { id: 1, artpath: nil } ]))

      assert_nil library.albums.sole.cover_path
    end
  end
end
