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

  # A double click, or the phone and the tablet at once: both presses look and
  # find nothing, and both insert. Nothing the app checks can catch that — by
  # the time it has looked, the answer is already stale. The database can, and
  # it is the only one that can, so it is the one that says no.
  test "the database is what refuses a heart already given" do
    @gaston.like(@track)

    assert_raises(ActiveRecord::RecordNotUnique) { insert_a_heart_for(@track) }
  end

  # And when it says no, the listener gets the heart they asked for — not a 500
  # over something that was already true.
  test "a heart given twice at once is a heart, not an error" do
    insert_a_heart_for(@track)

    assert @gaston.like(@track).persisted?
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

  private

  # Straight past the app, the way the other tab's insert arrives.
  def insert_a_heart_for(thing)
    Like.insert!({
      profile_id: @gaston.id, likeable_type: thing.class.name, likeable_id: thing.id,
      created_at: Time.current, updated_at: Time.current
    })
  end
end
