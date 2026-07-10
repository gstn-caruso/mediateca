require "test_helper"

class KeepingPlaylistsTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @first = Track.create!(title: "Desencuentro", path: "/music/mundo/01.flac", album: @album)
    @second = Track.create!(title: "El Pibe Tigre", path: "/music/mundo/02.flac", album: @album)
  end

  test "a playlist is created from the sidebar, and opens on its own page" do
    assert_difference -> { Playlist.count }, +1 do
      post playlists_path, params: { playlist: { name: "Road trip" } }
    end

    follow_redirect!
    assert_response :success
    assert_match "Road trip", response.body
  end

  test "a track is added from the album page, and lands back on it" do
    post playlist_entries_path(list), params: { track_id: @first.id }, headers: referred_from_album

    assert_redirected_to album_path(@album)
    assert_equal [ @first ], list.reload.tracks.to_a
  end

  test "a track is taken out again" do
    list.add(@first)

    assert_difference -> { PlaylistEntry.count }, -1 do
      delete playlist_entry_path(list, list.entries.sole)
    end
  end

  test "a track is moved up a place" do
    [ @first, @second ].each { |track| list.add(track) }

    patch playlist_entry_path(list, list.entries.second, by: -1)

    assert_equal [ @second, @first ], list.reload.tracks.to_a
  end

  test "a playlist is renamed" do
    patch playlist_path(list), params: { playlist: { name: "Rock" } }

    assert_equal "Rock", list.reload.name
  end

  test "a playlist is deleted" do
    list

    assert_difference -> { Playlist.count }, -1 do
      delete playlist_path(list)
    end
  end

  # There is no password. The only thing standing between two listeners is that
  # one's playlist cannot be found through the other.
  test "somebody else's playlist does not exist" do
    theirs = Profile.create!(name: "Ana").playlists.create!(name: "Private")

    get playlist_path(theirs)

    assert_response :not_found
  end

  test "and nothing can be added to it" do
    theirs = Profile.create!(name: "Ana").playlists.create!(name: "Private")

    post playlist_entries_path(theirs), params: { track_id: @first.id }

    assert_response :not_found
    assert_empty theirs.reload.tracks
  end

  private

  def list
    @list ||= @gaston.playlists.create!(name: "Road trip")
  end

  def referred_from_album
    { "HTTP_REFERER" => album_url(@album) }
  end
end
