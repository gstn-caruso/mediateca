require "test_helper"

class LikingAndHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @track = Track.create!(title: "Desencuentro", path: "/music/mundo/01.flac", album: @album)
  end

  test "a song is liked, and shows on the liked songs page" do
    post track_like_path(@track)

    assert @gaston.likes?(@track)
    get likes_path
    assert_match "Desencuentro", response.body
  end

  test "an album is liked too" do
    post album_like_path(@album)

    assert @gaston.likes?(@album)
  end

  test "a like is taken back by naming what was liked" do
    @gaston.like(@track)

    delete track_like_path(@track)

    refute @gaston.reload.likes?(@track)
  end

  # A like now names its owner through the route, so the only things that can be
  # liked are the ones that have a like route. Nothing else can even be asked
  # for, and a heart is no longer a way to load an arbitrary class.
  test "only tracks and albums can be liked" do
    post "/profiles/#{@gaston.id}/like"

    assert_response :not_found
    assert_empty @gaston.likes
  end

  test "what one profile likes, another does not see" do
    Profile.create!(name: "Ana").like(@track)

    get likes_path

    assert_no_match "Desencuentro", response.body
  end

  test "playing a track writes it into the history" do
    assert_difference -> { Play.count }, +1 do
      post plays_path, params: { track_id: @track.id }
    end

    assert_response :no_content
    assert_equal [ @album ], @gaston.recently_played_albums
  end

  test "the front page shows what was recently played" do
    @gaston.played(@track)

    get root_path

    assert_match "Recently played", response.body
  end

  test "nobody listening records nothing" do
    delete session_path

    post plays_path, params: { track_id: @track.id }

    assert_redirected_to profiles_path
  end
end
