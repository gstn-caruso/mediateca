require "test_helper"

module Music
  class ImporterTest < ActiveSupport::TestCase
    include SourceBuilders

    ENTORNO = "#{MUSIC_ROOT}/Almafuerte/1996 - Del entorno".freeze

    test "una fuente sin álbumes no importa nada" do
      Importer.new.import(source(albums: []))

      assert_equal 0, Artist.count
      assert_equal 0, Album.count
      assert_equal 0, Track.count
    end

    test "importa un álbum con su artista y sus tracks" do
      Importer.new.import(source(albums: [ source_album(
        directory: ENTORNO,
        title: "Del entorno",
        artist: "Almafuerte",
        year: 1996,
        genre: "heavy metal",
        album_type: "album",
        disc_total: 1,
        cover_path: "#{ENTORNO}/cover.jpg",
        tracks: [ source_track(path: "#{ENTORNO}/01 - Vamos a la calle.flac", title: "Vamos a la calle", track_no: 1, duration: 200.5) ]
      ) ]))

      assert_equal "Almafuerte", Artist.sole.name

      album = Album.sole
      assert_equal ENTORNO, album.directory
      assert_equal "Del entorno", album.title
      assert_equal 1996, album.year
      assert_equal "heavy metal", album.genre
      assert_equal "album", album.album_type
      assert_equal 1, album.disc_total
      assert_equal "#{ENTORNO}/cover.jpg", album.cover_path
      assert_equal Artist.sole, album.artist

      track = Track.sole
      assert_equal "#{ENTORNO}/01 - Vamos a la calle.flac", track.path
      assert_equal "Vamos a la calle", track.title
      assert_equal 1, track.track_no
      assert_equal 1, track.disc_no
      assert_in_delta 200.5, track.duration
      assert_equal album, track.album
    end

    # El escaneo va a correr cada vez que cambie la biblioteca; importar dos
    # veces la misma fuente no puede duplicar nada.
    test "importar dos veces la misma fuente no duplica nada" do
      albums = [ source_album(tracks: [ source_track ]) ]

      2.times { Importer.new.import(source(albums:)) }

      assert_equal 1, Artist.count
      assert_equal 1, Album.count
      assert_equal 1, Track.count
    end

    test "dos álbumes del mismo artista comparten una sola fila de artista" do
      Importer.new.import(source(albums: [
        source_album(directory: GUANACO, title: "Mundo Guanaco", artist: "Almafuerte"),
        source_album(directory: ENTORNO, title: "Del entorno", artist: "Almafuerte")
      ]))

      assert_equal 1, Artist.count
      assert_equal 2, Album.count
      assert_equal [ "Almafuerte" ], Album.all.map { |album| album.artist.name }.uniq
    end

    # El directorio es la identidad: el álbum es el mismo aunque le cambien el
    # título, el año o el género.
    test "reimportar un álbum que cambió lo actualiza en su lugar" do
      Importer.new.import(source(albums: [ source_album(directory: ENTORNO, title: "Del Entorno", year: 1996, genre: "") ]))
      Importer.new.import(source(albums: [ source_album(directory: ENTORNO, title: "Del entorno", year: 1997, genre: "heavy metal") ]))

      album = Album.sole
      assert_equal "Del entorno", album.title
      assert_equal 1997, album.year
      assert_equal "heavy metal", album.genre
    end

    # Un track que se renombró en disco es un track nuevo, y el viejo ya no está
    # ahí. Si no se limpian, el álbum acumula fantasmas que no se pueden sonar.
    test "los tracks que la fuente ya no reporta desaparecen del álbum" do
      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - viejo.flac", track_no: 1),
        source_track(path: "#{GUANACO}/02 - se queda.flac", track_no: 2)
      ]) ]))

      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/02 - se queda.flac", track_no: 2)
      ]) ]))

      assert_equal [ "#{GUANACO}/02 - se queda.flac" ], Track.pluck(:path)
    end

    # Un disco borrado del NAS no puede seguir apareciendo en la biblioteca.
    test "un álbum que la fuente ya no reporta desaparece" do
      Importer.new.import(source(albums: [
        source_album(directory: GUANACO, title: "Mundo Guanaco"),
        source_album(directory: ENTORNO, title: "Del entorno")
      ]))

      Importer.new.import(source(albums: [ source_album(directory: GUANACO, title: "Mundo Guanaco") ]))

      assert_equal [ "Mundo Guanaco" ], Album.pluck(:title)
    end

    test "un artista que se quedó sin álbumes desaparece" do
      Importer.new.import(source(albums: [ source_album(artist: "Almafuerte"), source_album(directory: ENTORNO, artist: "Hermética") ]))
      Importer.new.import(source(albums: [ source_album(artist: "Almafuerte") ]))

      assert_equal [ "Almafuerte" ], Artist.pluck(:name)
    end

    # Vaciar la fuente por error no puede vaciar la biblioteca: un NAS que no
    # montó se ve exactamente igual que una biblioteca borrada.
    test "una fuente vacía no borra la biblioteca entera" do
      Importer.new.import(source(albums: [ source_album ]))

      Importer.new.import(source(albums: []))

      assert_equal 1, Album.count
    end

    test "los tracks de un álbum multi-disco quedan ordenados por disco y número" do
      Importer.new.import(source(albums: [ source_album(disc_total: 2, tracks: [
        source_track(path: "#{GUANACO}/CD2/01.flac", disc_no: 2, track_no: 1, title: "primera del disco dos"),
        source_track(path: "#{GUANACO}/CD1/01.flac", disc_no: 1, track_no: 1, title: "primera del disco uno"),
        source_track(path: "#{GUANACO}/CD1/02.flac", disc_no: 1, track_no: 2, title: "segunda del disco uno")
      ]) ]))

      assert_equal [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ] ], Album.sole.tracks.map { |track| [ track.disc_no, track.track_no ] }
    end

    # 23 de los 75 álbumes del NAS traen genre = '' y no NULL.
    test "un género vacío se guarda como string vacío" do
      Importer.new.import(source(albums: [ source_album(genre: "") ]))

      assert_equal "", Album.sole.genre
    end

    test "un álbum sin carátula se importa igual" do
      Importer.new.import(source(albums: [ source_album(cover_path: nil) ]))

      assert_nil Album.sole.cover_path
    end
  end
end
