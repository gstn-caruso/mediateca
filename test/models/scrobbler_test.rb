require "test_helper"

# What a scrobbler is for: the songs you heard, told to Last.fm.
#
# They are held here first, in a queue that survives a restart, because the NAS
# this runs on is not always the machine with the internet — Last.fm asks for
# exactly that, and it is the difference between a scrobble delayed and a scrobble
# lost.
class ScrobblerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Lastfm.api = @lastfm = FakeLastfm.new
    @gaston = Profile.create!(name: "Gastón")
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist: @artist)
    @song = song("Desencuentro")
  end

  test "a listener without a Last.fm queues nothing" do
    @gaston.played(@song)

    assert_predicate Scrobble.all, :empty?
  end

  test "a song heard is a song queued, timed from when the music started" do
    connected
    started = 4.minutes.ago

    @gaston.played(@song, at: started)

    assert_equal @song, Scrobble.sole.track
    assert_in_delta started, Scrobble.sole.played_at, 1.second
  end

  # Last.fm's rule, and it is theirs to make: "The track must be longer than 30
  # seconds." It still counts as a play here — you heard it — but it is not a
  # thing Last.fm will take, so it is not a thing we queue.
  test "a song too short for Last.fm is played but never queued" do
    connected
    jingle = song("A Jingle", seconds: 20)

    @gaston.played(jingle)

    assert_equal 1, @gaston.times_played(jingle)
    assert_predicate Scrobble.all, :empty?
  end

  # "Scrobbles should be sent in order, therefore cached scrobbles should be sent
  # before new scrobbles." Last.fm asks for it, and a history out of order is a
  # history that reads wrong on their side forever.
  test "what was heard first is sent first, whatever order it was written down in" do
    connected
    @gaston.played(song("Later"), at: 1.minute.ago)
    @gaston.played(song("Earlier"), at: 1.hour.ago)

    @gaston.scrobbler.send_what_is_waiting

    assert_equal [ "Earlier", "Later" ], @lastfm.scrobbled.pluck(:track)
  end

  test "a song sent is a song not sent twice" do
    connected
    @gaston.played(@song)

    2.times { @gaston.scrobbler.send_what_is_waiting }

    assert_equal 1, @lastfm.scrobbled.size
    assert_predicate Scrobble.sole, :sent?
  end

  # Fifty is all Last.fm will take in one breath.
  test "a hundred and one songs go in three breaths" do
    connected
    101.times { |at| @gaston.played(song("Song #{at}"), at: at.minutes.ago) }

    assert_equal 3, breaths_taken { @gaston.scrobbler.send_what_is_waiting }
    assert_equal 101, @lastfm.scrobbled.size
  end

  # The one that eats a backfill, and the reason it is worth recording rather
  # than merely surviving: Last.fm says "too far in the past" inside a 200 OK,
  # with a code and no fuss, and a scrobbler that only checked the status would
  # swear it had sent them.
  test "a scrobble Last.fm quietly threw away says so" do
    Lastfm.api = FakeLastfm.new(ignoring: 3)
    connected
    @gaston.played(@song, at: 2.years.ago)

    @gaston.scrobbler.send_what_is_waiting

    assert_predicate Scrobble.sole, :sent?
    assert_not Scrobble.sole.taken?
    assert_equal 3, Scrobble.sole.ignored_as
  end

  # Last.fm is having a moment. The songs wait: that is the whole point of holding
  # them, and Last.fm will take them late.
  test "a Last.fm having a moment keeps the songs waiting" do
    connected
    @gaston.played(@song)
    Lastfm.api = FakeLastfm::Busy.new

    assert_raises(Lastfm::Api::Busy) { @gaston.scrobbler.send_what_is_waiting }

    assert_not_predicate Scrobble.sole, :sent?
  end

  # The listener revoked us on Last.fm's own settings page. There is nothing to
  # retry and nothing to keep: the account goes, the menu offers to connect again,
  # and the songs stay queued for whenever it is.
  test "a listener who revoked us is disconnected, and their songs keep waiting" do
    connected
    @gaston.played(@song)
    Lastfm.api = FakeLastfm::Revoked.new

    @gaston.scrobbler.send_what_is_waiting

    assert_not @gaston.reload.scrobbles?
    assert_not_predicate Scrobble.sole, :sent?
  end

  test "connecting queues the year you listened before you connected" do
    @gaston.played(@song, at: 8.months.ago)
    @gaston.played(@song, at: 3.days.ago)

    perform_enqueued_jobs { connected }

    assert_equal 2, Scrobble.count
    assert_equal 2, @lastfm.scrobbled.size
  end

  # The history goes out in the order it happened, which is what Last.fm asks for.
  test "the year goes out in the order you lived it" do
    @gaston.played(song("Last"), at: 1.day.ago)
    @gaston.played(song("First"), at: 1.year.ago)

    perform_enqueued_jobs { connected }

    assert_equal [ "First", "Last" ], @lastfm.scrobbled.pluck(:track)
  end

  test "a song too short for Last.fm is left out of the catch-up too" do
    @gaston.played(song("A Jingle", seconds: 20), at: 1.day.ago)

    perform_enqueued_jobs { connected }

    assert_predicate Scrobble.all, :empty?
  end

  # Disconnecting and connecting again is not a reason to scrobble your whole life
  # a second time.
  test "connecting again does not send it all a second time" do
    @gaston.played(@song, at: 8.months.ago)
    perform_enqueued_jobs { connected }

    perform_enqueued_jobs { connected }

    assert_equal 1, Scrobble.count
    assert_equal 1, @lastfm.scrobbled.size
  end

  # The loop that would have been. Last.fm hands over a listener's whole history —
  # a hundred thousand scrobbles — and those become plays here. Connect again, and
  # a catch-up that could not tell where a play came from would hand Last.fm back
  # its own history, every song of it, as if it were new listening.
  #
  # So a play knows where it was heard, and only the ones heard *here* are ever
  # told to anybody.
  test "what Last.fm told us is never told back to Last.fm" do
    @gaston.played(@song, at: 1.hour.ago)
    @gaston.heard_elsewhere(track: @song, at: 2.years.ago, from: "lastfm")

    connected
    @gaston.scrobbler.catch_up_on_the_history

    assert_equal 1, Scrobble.count
    assert_in_delta 1.hour.ago, Scrobble.sole.played_at, 1.second
  end

  private

  def connected
    @gaston.scrobbles_to(username: "gaston", session_key: "s3ss10nk3y")
  end

  def song(title, seconds: 200.0)
    Track.create!(title:, duration: seconds, path: "/music/mundo/#{title}.flac", album: @album)
  end

  # Last.fm counts a batch as one call, so the calls are what is counted.
  def breaths_taken
    before = @lastfm.scrobbled.size
    taken = 0
    @lastfm.define_singleton_method(:scrobble) do |songs, as:|
      taken += 1
      super(songs, as:)
    end

    yield
    assert_operator @lastfm.scrobbled.size, :>, before
    taken
  end
end
