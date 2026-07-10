require "test_helper"

class SearchingTest < ActionDispatch::IntegrationTest
  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    Track.create!(title: "Desencuentro", path: "/music/mundo/01.flac", album: @album)
  end

  test "an album is found by a piece of its title" do
    get search_path(q: "guana")

    assert_response :success
    assert_match "Mundo Guanaco", response.body
  end

  test "a song is found by a piece of its title" do
    get search_path(q: "encuen")

    assert_match "Desencuentro", response.body
  end

  test "a search that finds nothing says so, by name" do
    get search_path(q: "Piazzolla")

    assert_response :success
    assert_match "No results", response.body
    assert_match "Piazzolla", response.body
  end

  test "arriving with an empty search invites you to type" do
    get search_path

    assert_response :success
    assert_match "Search your library", response.body
  end

  test "nobody listening cannot search either" do
    delete session_path

    get search_path(q: "guana")

    assert_redirected_to profiles_path
  end
end
