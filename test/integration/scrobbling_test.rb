require "test_helper"

# The player tells the server two different things about one song, at two
# different moments, and they are not the same news. At the first note: this is
# on right now. At the halfway mark: this was listened to. Last.fm wants both,
# and wants them exactly that way round.
class ScrobblingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Lastfm.api = FakeLastfm.new
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @track = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/01.flac", album:)
  end

  test "the song that started is announced to Last.fm at once" do
    connected

    assert_enqueued_with job: NowPlayingJob do
      post now_playing_path, params: { track_id: @track.id }
    end

    assert_response :no_content
  end

  # Nobody to tell. The player is told not to bother asking, but the door is a
  # door, and a listener without a Last.fm knocking on it gets a shrug and no job.
  test "a listener with no Last.fm announces to nobody" do
    assert_no_enqueued_jobs only: NowPlayingJob do
      post now_playing_path, params: { track_id: @track.id }
    end
  end

  test "a song listened to is queued for Last.fm and something is set to send it" do
    connected

    assert_enqueued_with job: ScrobbleJob do
      post plays_path, params: { track_id: @track.id, started_at: 3.minutes.ago.to_i }
    end

    assert_equal @track, Scrobble.sole.track
    assert_not_predicate Scrobble.sole, :sent?
  end

  test "a listener with no Last.fm queues nothing" do
    assert_no_enqueued_jobs only: ScrobbleJob do
      post plays_path, params: { track_id: @track.id }
    end

    assert_predicate Scrobble.all, :empty?
  end

  private

  def connected
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end
end
