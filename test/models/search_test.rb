require "test_helper"

class SearchTest < ActiveSupport::TestCase
  setup do
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    Track.create!(title: "Desencuentro", path: "/music/mundo/01.flac", album:)
  end

  test "a search for nothing finds nothing, rather than everything" do
    [ "", "   ", nil ].each do |nothing|
      search = Search.new(nothing)

      assert_empty search.artists, "#{nothing.inspect} dumped the artists"
      assert_empty search.albums
      assert_empty search.tracks
    end
  end

  test "an artist is found by a piece of its name" do
    assert_equal [ "Almafuerte" ], Search.new("mafue").artists.map(&:name)
  end

  test "an album is found by a piece of its title" do
    assert_equal [ "Mundo Guanaco" ], Search.new("guana").albums.map(&:title)
  end

  test "a track is found by a piece of its title" do
    assert_equal [ "Desencuentro" ], Search.new("encuen").tracks.map(&:title)
  end

  test "typing in lower case still finds a capitalised name" do
    assert_equal [ "Almafuerte" ], Search.new("ALMAfuerte").artists.map(&:name)
  end

  # In SQL, % and _ are wildcards. Unescaped, a listener typing either of them
  # gets handed the entire library.
  test "a percent sign is a character somebody typed, not a wildcard" do
    assert_empty Search.new("%").artists
    assert_empty Search.new("%").albums
    assert_empty Search.new("%").tracks
  end

  test "an underscore is a character somebody typed, not a wildcard" do
    assert_empty Search.new("_").artists
  end

  # Escaping the wildcard is only half of it: the escape character has to be
  # declared, or SQLite reads the backslash as a backslash and finds neither the
  # wildcard nor the literal.
  test "a band with a percent sign in its name is found by that percent sign" do
    Artist.create!(name: "100% Real")

    assert_equal [ "100% Real" ], Search.new("%").artists.map(&:name)
  end

  test "a band with an underscore in its name is found by that underscore" do
    Artist.create!(name: "Lo_Fi")

    assert_equal [ "Lo_Fi" ], Search.new("_").artists.map(&:name)
  end

  test "a search that matches nothing finds nothing" do
    assert_empty Search.new("Piazzolla").artists
  end
end
