require "test_helper"

class PlaylistTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @first = track("Desencuentro")
    @second = track("El Pibe Tigre")
    @third = track("Dijo El Droguero")
  end

  test "a playlist starts empty" do
    assert_empty playlist.tracks
  end

  test "a playlist needs a name" do
    refute @gaston.playlists.build(name: " ").valid?
  end

  # Two people can each keep a playlist called Rock; one person cannot keep two.
  test "a name is taken only within the profile that owns it" do
    @gaston.playlists.create!(name: "Rock")

    refute @gaston.playlists.build(name: "Rock").valid?
    assert Profile.create!(name: "Ana").playlists.build(name: "Rock").valid?
  end

  test "tracks come out in the order they went in, not the order of the album" do
    list = playlist
    [ @third, @first, @second ].each { |track| list.add(track) }

    assert_equal [ @third, @first, @second ], list.reload.tracks.to_a
  end

  # Spotify lets you, and a playlist is not a set.
  test "the same track can be added twice" do
    list = playlist
    2.times { list.add(@first) }

    assert_equal [ @first, @first ], list.reload.tracks.to_a
  end

  test "removing a track leaves the rest in order" do
    list = playlist
    [ @first, @second, @third ].each { |track| list.add(track) }

    list.entries.find_by(track: @second).destroy!

    assert_equal [ @first, @third ], list.reload.tracks.to_a
  end

  test "a playlist can be reordered" do
    list = playlist
    [ @first, @second, @third ].each { |track| list.add(track) }
    reversed = list.entries.reverse.map(&:id)

    list.reorder(reversed)

    assert_equal [ @third, @second, @first ], list.reload.tracks.to_a
  end

  # Reordering by ids from another playlist would silently steal its entries.
  test "reordering only touches its own entries" do
    mine = playlist
    mine.add(@first)
    theirs = @gaston.playlists.create!(name: "Theirs")
    stolen = theirs.add(@second)

    mine.reorder([ stolen.id ])

    assert_equal [ @second ], theirs.reload.tracks.to_a
  end

  test "a profile taking its leave takes its playlists with it" do
    playlist.add(@first)

    assert_difference -> { Playlist.count }, -1 do
      @gaston.destroy!
    end
  end

  test "a track deleted from the catalog leaves no dangling entry" do
    playlist.add(@first)

    assert_difference -> { PlaylistEntry.count }, -1 do
      @first.destroy!
    end
  end

  test "a track moves one place up, and the one it passed moves down" do
    list = playlist
    [ @first, @second, @third ].each { |track| list.add(track) }

    list.move(list.entries.second, by: -1)

    assert_equal [ @second, @first, @third ], list.reload.tracks.to_a
  end

  test "the first track cannot climb any higher, and nothing shifts" do
    list = playlist
    [ @first, @second ].each { |track| list.add(track) }

    list.move(list.entries.first, by: -1)

    assert_equal [ @first, @second ], list.reload.tracks.to_a
  end

  test "the last track cannot fall any further" do
    list = playlist
    [ @first, @second ].each { |track| list.add(track) }

    list.move(list.entries.last, by: +1)

    assert_equal [ @first, @second ], list.reload.tracks.to_a
  end

  private

  def playlist
    @playlist ||= @gaston.playlists.create!(name: "Road trip")
  end

  def track(title)
    Track.create!(title:, path: "/music/mundo/#{title}.flac", album: @album)
  end
end
