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

  test "connecting queues the year you listened before you connected" do
    @gaston.played(@song, at: 8.months.ago)
    @gaston.played(@song, at: 3.days.ago)

    perform_enqueued_jobs { connect }

    assert_equal 2, Scrobble.count
    assert_equal 2, @lastfm.scrobbled.size
  end

  # The history goes out in the order it happened, which is what Last.fm asks for.
  test "the year goes out in the order you lived it" do
    @gaston.played(song("Last"), at: 1.day.ago)
    @gaston.played(song("First"), at: 1.year.ago)

    perform_enqueued_jobs { connect }

    assert_equal [ "First", "Last" ], @lastfm.scrobbled.pluck(:track)
  end

  test "a song too short for Last.fm is left out of the catch-up too" do
    @gaston.played(song("A Jingle", seconds: 20), at: 1.day.ago)

    perform_enqueued_jobs { connect }

    assert_predicate Scrobble.all, :empty?
  end

  # Disconnecting and connecting again is not a reason to scrobble your whole life
  # a second time.
  test "connecting again does not send it all a second time" do
    @gaston.played(@song, at: 8.months.ago)
    perform_enqueued_jobs { connect }

    perform_enqueued_jobs { connect }

    assert_equal 1, Scrobble.count
    assert_equal 1, @lastfm.scrobbled.size
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

  private

  def connect
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end

  def song(title, seconds: 200.0)
    Track.create!(title:, duration: seconds, path: "/music/mundo/#{title}.flac", album: @album)
  end
end
