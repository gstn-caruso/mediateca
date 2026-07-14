require "test_helper"

# Hiding an artist is not deleting one. The records stay on the disk, the rows
# stay in the catalog, and the songs stay in the playlists somebody put them in
# — they simply stop being *shown*. Everything the library offers on its own
# stops offering them; everything you ask for by name still answers.
class HidingArtistsTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    @almafuerte = Artist.create!(name: "Almafuerte")
    @guanaco = Album.create!(directory: "/music/guanaco", title: "Mundo Guanaco", year: 1995, artist: @almafuerte)
    @desencuentro = Track.create!(title: "Desencuentro", path: "/music/guanaco/01.flac", album: @guanaco)
  end

  test "a hidden artist leaves the library" do
    @gaston.hide(@almafuerte)

    get root_path

    assert_select "a[href=?]", artist_path(@almafuerte), false
  end

  # The records are the same library seen the other way round. An artist hidden
  # in one turn of the rail and standing there in the next would be hidden in
  # neither.
  test "a hidden artist takes their records with them" do
    @gaston.hide(@almafuerte)

    get root_path

    assert_select "a[href=?]", album_path(@guanaco), false
  end

  test "a hidden artist's songs leave your hearts" do
    @gaston.like(@desencuentro)
    @gaston.hide(@almafuerte)

    get likes_path

    assert_select "a[href=?]", album_path(@guanaco), false
    assert_equal 0, @gaston.reload.liked_songs_count
  end

  # The entry is not thrown away — hiding is not deleting, and a listener who
  # changes their mind wants the list they made back, not a list with a hole in
  # it. The row is simply not drawn.
  test "a hidden artist's songs leave the playlists they are in, and come back" do
    playlist = @gaston.playlists.create!(name: "Asado")
    playlist.add(@desencuentro)

    @gaston.hide(@almafuerte)
    get playlist_path(playlist)
    assert_select "li", text: /Desencuentro/, count: 0

    @gaston.unhide(@almafuerte)
    get playlist_path(playlist)
    assert_select "li", text: /Desencuentro/

    assert_equal 1, playlist.entries.count
  end

  # The whole of what "hidden" means: out of sight, not out of reach. Somebody
  # who types the name is not being recommended anything — they are asking.
  test "searching by hand still finds a hidden artist" do
    @gaston.hide(@almafuerte)

    get search_path, params: { q: "Almafuerte" }

    assert_select "a[href=?]", artist_path(@almafuerte)
  end

  # And their page still answers, which is where the hiding is taken back.
  test "a hidden artist still has a page" do
    @gaston.hide(@almafuerte)

    get artist_path(@almafuerte)

    assert_response :success
    assert_select "a[href=?]", album_path(@guanaco)
  end

  test "an artist hidden by one listener is still there for another" do
    @gaston.hide(@almafuerte)

    listening_as("Ana")
    get root_path

    assert_select "a[href=?]", artist_path(@almafuerte)
  end
end
