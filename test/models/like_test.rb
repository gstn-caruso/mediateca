require "test_helper"

class LikeTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @track = Track.create!(title: "Desencuentro", path: "/music/mundo/01.flac", album: @album)
  end

  test "a track can be liked, and an album too" do
    @gaston.like(@track)
    @gaston.like(@album)

    assert @gaston.likes?(@track)
    assert @gaston.likes?(@album)
  end

  test "liking twice is still liking once" do
    2.times { @gaston.like(@track) }

    assert_equal 1, @gaston.likes.count
  end

  test "what one profile likes, another does not" do
    @gaston.like(@track)

    refute Profile.create!(name: "Ana").likes?(@track)
  end

  test "a like can be taken back" do
    @gaston.like(@track)

    @gaston.unlike(@track)

    refute @gaston.likes?(@track)
  end

  test "liked songs come back newest first, the way Spotify shows them" do
    older = Track.create!(title: "El Pibe Tigre", path: "/music/mundo/02.flac", album: @album)
    @gaston.like(older)
    @gaston.like(@track)

    assert_equal [ @track, older ], @gaston.liked_tracks.to_a
  end

  test "deleting a track takes its likes with it" do
    @gaston.like(@track)

    assert_difference -> { Like.count }, -1 do
      @track.destroy!
    end
  end
end
