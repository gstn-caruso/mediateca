require "test_helper"

# You have been listening to this library for a year before you ever told it about
# Last.fm. That year is sitting right there, and it is the whole point of having
# kept it.
#
# So connecting sends it — and then says what actually became of it, which is the
# part that matters. Last.fm takes a scrobble late, but not *any* late: it throws
# away anything "too far in the past", it never says how far in its documentation,
# and it throws it away inside a 200 OK. A quieter app would have shown a spinner,
# said "done", and sent a year of listening into a hole.
class CatchingUpOnLastfmTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Lastfm.api = @lastfm = FakeLastfm.new
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @song = song("Desencuentro")
  end

  # The honest part. Last.fm took the recent one and quietly binned the old one,
  # and it said so in a code inside a perfectly successful response.
  test "the Last.fm page says what got through and what was too old" do
    Lastfm.api = FakeLastfm.new(ignoring: 3)
    @gaston.played(@song, at: 2.years.ago)
    perform_enqueued_jobs { connect }

    get scrobbler_path

    assert_match "1", response.body
    assert_match(/too old/i, response.body)
  end

  test "the Last.fm page says who you are over there" do
    connect

    get scrobbler_path

    assert_match "gaston", response.body
    assert_select "a[href=?]", "https://www.last.fm/user/gaston"
  end

  test "a listener with no Last.fm has no Last.fm page" do
    get scrobbler_path

    assert_redirected_to root_path
  end

  # The other direction, and the one that actually works: the years Last.fm kept
  # before this library existed.
  test "asking Last.fm for the history it kept sets something long-running going" do
    connect

    assert_enqueued_with job: ImportFromLastfmJob do
      post import_scrobbler_path
    end

    assert_redirected_to scrobbler_path
    assert_match(/Bringing your Last.fm home/i, flash[:notice])
  end

  test "a listener with no Last.fm has nothing to bring home" do
    assert_no_enqueued_jobs only: ImportFromLastfmJob do
      post import_scrobbler_path
    end

    assert_redirected_to root_path
  end

  private

  def connect
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end

  def song(title, seconds: 200.0)
    Track.create!(title:, duration: seconds, path: "/music/mundo/#{title}.flac", album: @album)
  end
end
