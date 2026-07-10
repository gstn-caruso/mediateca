require "test_helper"

module Music
  class LibraryTest < ActiveSupport::TestCase
    include SourceBuilders

    test "without beets, the library is whatever is on disk" do
      library = Library.new(disk: source(albums: [ source_album(title: "Toxicity") ]))

      assert_equal [ "Toxicity" ], library.albums.map(&:title)
    end

    # 270 of the NAS's flacs aren't in beets, along with 4 whole artists.
    test "an album beets doesn't know about still shows up" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: "/m/Indio Solari/2010 - X", title: "X") ]),
        beets: source(albums: [])
      )

      assert_equal [ "X" ], library.albums.map(&:title)
    end

    # beets has 3 System of a Down albums pointing at files that no longer
    # exist. Nothing that isn't on disk can play.
    test "an album only beets knows about doesn't appear" do
      library = Library.new(
        disk: source(albums: []),
        beets: source(albums: [ source_album(directory: "/m/System of a Down/2001 - Toxicity") ])
      )

      assert_empty library.albums
    end

    test "beets enriches the metadata of the album that shares its directory" do
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

    # beets picked the back cover for Almafuerte's 6 albums: cover.1.jpg weighs
    # exactly the same as "Cover back.jpg". On covers, the disc knows better.
    test "the disc picks the cover, not beets" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, cover_path: "#{GUANACO}/cover.jpg") ]),
        beets: source(albums: [ source_album(directory: GUANACO, cover_path: "#{GUANACO}/cover.1.jpg") ])
      )

      assert_equal "#{GUANACO}/cover.jpg", library.albums.sole.cover_path
    end

    test "data beets doesn't have doesn't overwrite the disc's" do
      library = Library.new(
        disk: source(albums: [ source_album(directory: GUANACO, title: "Mundo guanaco", genre: "metal") ]),
        beets: source(albums: [ source_album(directory: GUANACO, title: nil, genre: "") ])
      )

      album = library.albums.sole
      assert_equal "Mundo guanaco", album.title
      assert_equal "metal", album.genre
    end

    test "tracks are the disc's, with beets' titles wherever available" do
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

    test "a track only beets knows about isn't invented" do
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
