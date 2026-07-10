require "test_helper"

module Music
  class LibraryTest < ActiveSupport::TestCase
    include SourceBuilders

    test "sin beets, la biblioteca es lo que hay en disco" do
      library = Library.new(disk: source(albums: [ source_album(title: "Toxicity") ]))

      assert_equal [ "Toxicity" ], library.albums.map(&:title)
    end

    # 270 flac del NAS no están en beets, y 4 artistas enteros con ellos.
    test "un álbum que beets no conoce igual aparece" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: "/m/Indio Solari/2010 - X", title: "X") ]),
        beets: source(albums: [])
      )

      assert_equal [ "X" ], library.albums.map(&:title)
    end

    # beets tiene 3 álbumes de System of a Down apuntando a archivos que ya no
    # existen. Nada que no esté en disco puede sonar.
    test "un álbum que solo conoce beets no aparece" do
      library = Library.new(
        disk: source(albums: []),
        beets: source(albums: [ source_album(directory: "/m/System of a Down/2001 - Toxicity") ])
      )

      assert_empty library.albums
    end

    test "beets mejora la metadata del álbum que comparte directorio" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, title: "mundo guanaco", artist: "almafuerte", year: nil, genre: nil) ]),
        beets: source(albums: [ source_album(directory: GUANACO, title: "Mundo Guanaco", artist: "Almafuerte", year: 1995, genre: "heavy metal", album_type: "album") ])
      )

      album = library.albums.sole
      assert_equal "Mundo Guanaco", album.title
      assert_equal "Almafuerte", album.artist
      assert_equal 1995, album.year
      assert_equal "heavy metal", album.genre
      assert_equal "album", album.album_type
    end

    # beets eligió la contratapa para los 6 álbumes de Almafuerte: cover.1.jpg
    # pesa exactamente lo mismo que "Cover back.jpg". En carátulas el disco sabe
    # más.
    test "la carátula la elige el disco, no beets" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, cover_path: "#{GUANACO}/cover.jpg") ]),
        beets: source(albums: [ source_album(directory: GUANACO, cover_path: "#{GUANACO}/cover.1.jpg") ])
      )

      assert_equal "#{GUANACO}/cover.jpg", library.albums.sole.cover_path
    end

    test "un dato que beets no tiene no pisa al del disco" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, title: "Mundo guanaco", genre: "metal") ]),
        beets: source(albums: [ source_album(directory: GUANACO, title: nil, genre: "") ])
      )

      album = library.albums.sole
      assert_equal "Mundo guanaco", album.title
      assert_equal "metal", album.genre
    end

    test "los tracks son los del disco, con los títulos de beets donde los haya" do
      disk_tracks = [
        source_track(path: "#{GUANACO}/01.flac", title: "dijo el droguero al drogador", track_no: 1),
        source_track(path: "#{GUANACO}/02.flac", title: "desencuentro", track_no: 2)
      ]
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, tracks: disk_tracks) ]),
        beets: source(albums: [ source_album(directory: GUANACO, tracks: [
          source_track(path: "#{GUANACO}/01.flac", title: "Dijo El Droguero Al Drogador", track_no: 1)
        ]) ])
      )

      titles = library.albums.sole.tracks.map(&:title)
      assert_equal [ "Dijo El Droguero Al Drogador", "desencuentro" ], titles
    end

    test "un track que solo conoce beets no se inventa" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, tracks: [ source_track(path: "#{GUANACO}/01.flac") ]) ]),
        beets: source(albums: [ source_album(directory: GUANACO, tracks: [
          source_track(path: "#{GUANACO}/01.flac"),
          source_track(path: "#{GUANACO}/borrado.flac")
        ]) ])
      )

      assert_equal [ "#{GUANACO}/01.flac" ], library.albums.sole.tracks.map(&:path)
    end
  end
end
