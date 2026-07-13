require "test_helper"

# A heart given here is a heart given there. Last.fm calls it loving a track, and
# it is the same gesture — so it travels, and it travels the same way a scrobble
# does: queued first, sent after, kept until it can be.
#
# What is queued is the *intent*, not the gesture. Heart a song and unheart it
# before the queue drains and Last.fm is told once, correctly: the last thing you
# meant is the only thing it needs to hear.
class LovingOnLastfmTest < ActiveSupport::TestCase
  setup do
    Lastfm.api = @lastfm = FakeLastfm.new
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/01.flac", album: @album)
  end

  test "a listener without a Last.fm queues nothing" do
    @gaston.like(@song)

    assert_predicate Love.all, :empty?
  end

  test "a heart given is a love queued" do
    connected

    @gaston.like(@song)

    assert_predicate Love.sole, :loved?
    assert_equal @song, Love.sole.track
  end

  test "a heart taken back is an unlove queued" do
    connected
    @gaston.like(@song)
    drained

    @gaston.unlike(@song)

    assert_not_predicate Love.sole, :loved?
  end

  # The last thing you meant is the only thing Last.fm needs to hear.
  test "hearting and unhearting before it drains tells Last.fm once" do
    connected

    @gaston.like(@song)
    @gaston.unlike(@song)
    drained

    assert_empty @lastfm.loved
    assert_equal [ "Desencuentro" ], @lastfm.unloved.pluck(:track)
  end

  test "a love sent is a love not sent twice" do
    connected
    @gaston.like(@song)

    2.times { drained }

    assert_equal 1, @lastfm.loved.size
  end

  test "an album hearted is not a track Last.fm has ever heard of" do
    connected

    @gaston.like(@album)

    assert_predicate Love.all, :empty?
  end

  # The same bargain the scrobbles strike: Last.fm having a moment is not a heart
  # lost, it is a heart waiting.
  test "a Last.fm nobody can reach keeps the heart waiting" do
    connected
    @gaston.like(@song)
    Lastfm.api = FakeLastfm::Unreachable.new

    assert_raises(Lastfm::Api::Unreachable) { drained }

    assert_not_predicate Love.sole, :sent?
  end

  private

  def connected
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end

  def drained
    @gaston.scrobbler.send_what_is_waiting
  end
end
