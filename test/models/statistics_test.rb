require "test_helper"

# What a hundred thousand rows add up to. The easy mistake would be to count only
# the songs on the disk — which would put whatever you happen to *own* at the top
# of a chart about what you *play*.
class StatisticsTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Elliott Smith")
    @either = Album.create!(directory: "/music/either", title: "Either/Or", artist:)
    @angeles = Track.create!(title: "Angeles", duration: 170.0, path: "/music/either/1.flac", album: @either)
  end

  test "a listener who has heard nothing has no standings" do
    assert_not_predicate Statistics.new(@gaston), :any?
  end

  test "the song you played most is at the top" do
    3.times { |at| @gaston.played(@angeles, at: at.hours.ago) }
    heard "Pappo", "Desconfío", times: 1

    top = Statistics.new(@gaston).songs.first

    assert_equal "Angeles", top.name
    assert_equal 3, top.plays
  end

  # The one worth a test of its own. A song you do not own is a song you listened
  # to, and a chart that counted only what is on the disk would be a chart about
  # the disk.
  test "a song you do not own can be the song you played most" do
    @gaston.played(@angeles)
    heard "Pappo", "Desconfío", times: 9

    top = Statistics.new(@gaston).songs.first

    assert_equal "Desconfío", top.name
    assert_equal 9, top.plays
    assert_nil top.album, "there is no record here to point at"
  end

  test "artists are counted across everything they sang, owned or not" do
    2.times { @gaston.played(@angeles) }
    heard "Elliott Smith", "Say Yes", times: 3

    top = Statistics.new(@gaston).artists.first

    assert_equal "Elliott Smith", top.name
    assert_equal 5, top.plays, "two you own and three you do not are five you listened to"
  end

  # Records are the exception, and deliberately: a song you do not own is off no
  # record this house has ever seen, and a chart of records you cannot put on is
  # not a chart anybody wants.
  test "the records chart is only records this house has" do
    @gaston.played(@angeles)
    heard "Pappo", "Desconfío", times: 9

    records = Statistics.new(@gaston).records

    assert_equal [ "Either/Or" ], records.map(&:name)
    assert_equal @either, records.first.album
  end

  test "this month is not all time" do
    @gaston.played(@angeles, at: 2.months.ago)

    assert_not_predicate Statistics.new(@gaston, span: "month"), :any?
    assert_predicate Statistics.new(@gaston, span: "ever"), :any?
  end

  test "a span nobody asked for is the year" do
    assert_equal "year", Statistics.new(@gaston, span: "fortnight").span
  end

  private

  def heard(who, what, times:)
    gap = @gaston.misses(artist: who, title: what)

    times.times { |at| @gaston.heard_elsewhere(absence: gap, at: at.hours.ago, from: "lastfm") }
  end
end
