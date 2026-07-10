require "test_helper"

module Music
  class ImporterTest < ActiveSupport::TestCase
    include BeetsBuilders

    test "una fuente sin álbumes no importa nada" do
      Importer.new.import(source(albums: []))

      assert_equal 0, Artist.count
      assert_equal 0, Album.count
      assert_equal 0, Track.count
    end

    test "importa un álbum con su artista y sus tracks" do
      Importer.new.import(source(albums: [ beets_album(
        beets_id: 7,
        title: "Del entorno",
        artist: "Almafuerte",
        year: 1996,
        genre: "heavy metal",
        album_type: "album",
        disc_total: 1,
        cover_path: "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/cover.jpg",
        tracks: [ beets_track(beets_id: 10, title: "Vamos a la calle", track_no: 1, duration: 200.5, path: "/tmp/01.flac") ]
      ) ]))

      assert_equal "Almafuerte", Artist.sole.name

      album = Album.sole
      assert_equal 7, album.beets_id
      assert_equal "Del entorno", album.title
      assert_equal 1996, album.year
      assert_equal "heavy metal", album.genre
      assert_equal "album", album.album_type
      assert_equal 1, album.disc_total
      assert_equal "/mnt/data/multimedia/Música/Almafuerte/1996 - Del entorno/cover.jpg", album.cover_path
      assert_equal Artist.sole, album.artist

      track = Track.sole
      assert_equal 10, track.beets_id
      assert_equal "Vamos a la calle", track.title
      assert_equal 1, track.track_no
      assert_equal 1, track.disc_no
      assert_in_delta 200.5, track.duration
      assert_equal "/tmp/01.flac", track.path
      assert_equal album, track.album
    end

    # El escaneo va a correr cada vez que cambie la biblioteca; importar dos
    # veces la misma fuente no puede duplicar nada.
    test "importar dos veces la misma fuente no duplica nada" do
      albums = [ beets_album(tracks: [ beets_track ]) ]

      2.times { Importer.new.import(source(albums:)) }

      assert_equal 1, Artist.count
      assert_equal 1, Album.count
      assert_equal 1, Track.count
    end

    test "dos álbumes del mismo artista comparten una sola fila de artista" do
      Importer.new.import(source(albums: [
        beets_album(beets_id: 1, title: "Mundo Guanaco", artist: "Almafuerte"),
        beets_album(beets_id: 2, title: "Del entorno", artist: "Almafuerte")
      ]))

      assert_equal 1, Artist.count
      assert_equal 2, Album.count
      assert_equal [ "Almafuerte" ], Album.all.map { |album| album.artist.name }.uniq
    end

    test "reimportar un álbum que cambió lo actualiza en su lugar" do
      Importer.new.import(source(albums: [ beets_album(beets_id: 7, title: "Del Entorno", year: 1996, genre: "") ]))
      Importer.new.import(source(albums: [ beets_album(beets_id: 7, title: "Del entorno", year: 1997, genre: "heavy metal") ]))

      album = Album.sole
      assert_equal "Del entorno", album.title
      assert_equal 1997, album.year
      assert_equal "heavy metal", album.genre
    end

    test "los tracks de un álbum multi-disco quedan ordenados por disco y número" do
      Importer.new.import(source(albums: [ beets_album(disc_total: 2, tracks: [
        beets_track(beets_id: 30, disc_no: 2, track_no: 1, title: "primera del disco dos", path: "/tmp/d2t1.flac"),
        beets_track(beets_id: 10, disc_no: 1, track_no: 1, title: "primera del disco uno", path: "/tmp/d1t1.flac"),
        beets_track(beets_id: 20, disc_no: 1, track_no: 2, title: "segunda del disco uno", path: "/tmp/d1t2.flac")
      ]) ]))

      assert_equal [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ] ], Album.sole.tracks.map { |track| [ track.disc_no, track.track_no ] }
    end

    # 23 de los 75 álbumes del NAS traen genre = '' y no NULL.
    test "un género vacío se guarda como string vacío" do
      Importer.new.import(source(albums: [ beets_album(genre: "") ]))

      assert_equal "", Album.sole.genre
    end

    # 3 de los 75 álbumes apuntan a carátulas que ya no están en disco. El
    # importer guarda el path igual; validar la existencia es de quien sirve.
    test "un álbum sin carátula se importa igual" do
      Importer.new.import(source(albums: [ beets_album(cover_path: nil) ]))

      assert_nil Album.sole.cover_path
    end
  end
end
