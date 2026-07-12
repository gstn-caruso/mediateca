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

  # A double click, or the phone and the tablet at once: both adds read the same
  # last position and both claim the one after it. The list would then hold two
  # songs in one place, in an order decided by nothing, and pressing ▲ on either
  # would appear to do nothing at all. Only the database can refuse that.
  test "two songs cannot hold the same place in the list" do
    list = playlist
    list.add(@first)

    assert_raises(ActiveRecord::RecordNotUnique) do
      list.entries.insert!({ track_id: @second.id, position: 1, created_at: Time.current, updated_at: Time.current })
    end
  end

  test "a song added while another was landing still lands, behind it" do
    list = playlist
    list.add(@first)
    list.add(@second)

    assert_equal [ 1, 2 ], list.entries.pluck(:position)
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

  # Moving a song is the only thing that reorders a playlist, so it is the only
  # thing that has to keep the places 1..n with none repeated — which is what the
  # index demands and what ▲ and ▼ read.
  test "moving a song leaves the places whole" do
    list = playlist
    [ @first, @second, @third ].each { |track| list.add(track) }

    list.move(list.entries.last, by: -1)

    assert_equal [ @first, @third, @second ], list.reload.tracks.to_a
    assert_equal [ 1, 2, 3 ], list.entries.reload.pluck(:position)
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
