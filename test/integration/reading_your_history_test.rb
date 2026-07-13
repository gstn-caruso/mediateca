require "test_helper"

# A hundred and twenty-seven thousand songs, in the order you heard them.
#
# The library is a shelf: it says what you own. The history is the other thing a
# record collection quietly keeps, and until now this app kept it and never showed
# it to anybody — it fed the counters and the suggestions and was never once read
# back. It is the most interesting table in the database.
class ReadingYourHistoryTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Elliott Smith")
    album = Album.create!(directory: "/music/either", title: "Either/Or", artist:)
    @angeles = Track.create!(title: "Angeles", duration: 170.0, path: "/music/either/1.flac", album:)
  end

  test "the songs you heard, newest first" do
    @gaston.played(@angeles, at: 2.hours.ago)
    @gaston.heard_elsewhere(track: @angeles, at: 3.days.ago, from: "lastfm")

    get history_path

    assert_select "[data-history-song]", count: 2
    assert_match "Angeles", response.body
  end

  # The songs you do not own are in it. They are most of it, for anybody who has
  # been scrobbling for a decade, and a history that dropped them would be a
  # history of the wrong life.
  test "a song you do not own is in your history all the same" do
    @gaston.heard_elsewhere(absence: @gaston.misses(artist: "Pappo", title: "Desconfío"),
                            at: 1.day.ago, from: "lastfm")

    get history_path

    assert_match "Desconfío", response.body
    assert_match "Pappo", response.body
  end

  # Where a listen came from: this app, or somebody else's records of it.
  test "the history says which listening happened here" do
    @gaston.played(@angeles, at: 1.hour.ago)
    @gaston.heard_elsewhere(track: @angeles, at: 2.hours.ago, from: "lastfm")

    get history_path

    assert_match "Last.fm", response.body
  end

  test "a day is a day: what you heard is grouped under it" do
    @gaston.played(@angeles, at: 2.hours.ago)
    @gaston.played(@angeles, at: 8.days.ago)

    get history_path

    assert_select "[data-history-day]", count: 2
  end

  test "a listener who has heard nothing is told so" do
    get history_path

    assert_match(/Nothing yet/i, response.body)
  end

  test "what one listener heard, another has not" do
    Profile.create!(name: "Ana").played(@angeles)

    get history_path

    assert_select "[data-history-song]", count: 0
  end
end
