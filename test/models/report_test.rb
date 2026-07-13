require "test_helper"

# The one figure only a library can hand you: not how much you listened, which
# every service says, but how much of what you love it hasn't got.
class ReportTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/1.flac", album: @album)
  end

  test "a listener who has heard nothing has nothing to report" do
    assert_not_predicate Report.new(@gaston), :any?
  end

  test "the headline is how much of it is not on the disk" do
    2.times { |at| @gaston.played(@song, at: at.hours.ago) }
    heard "Pappo", "Desconfío", times: 8

    report = Report.new(@gaston)

    assert_equal 10, report.plays
    assert_equal 2, report.ours
    assert_equal 8, report.elsewhere
    assert_equal 80, report.missing_share
  end

  test "the years are the shape of a life" do
    @gaston.heard_elsewhere(track: @song, at: 3.years.ago, from: "lastfm")
    2.times { @gaston.played(@song) }

    years = Report.new(@gaston).by_year

    assert_equal 2, years.size
    assert_equal 2, years[Date.current.year.to_s]
  end

  test "the hours say when you actually listen" do
    at = Time.current.utc.change(hour: 3)
    3.times { |n| @gaston.played(@song, at: at + n.minutes) }

    report = Report.new(@gaston)

    assert_equal 3, report.loudest_hour
    assert_equal 24, report.by_hour.size
  end

  # The shopping list. It is the section the whole app was built to be able to
  # write, and no shop has any reason to.
  test "what is wanted is what you play and cannot play here" do
    @gaston.played(@song)
    heard "Pappo", "Desconfío", times: 9

    wanted = Report.new(@gaston).wanted

    assert_equal [ "Pappo" ], wanted.map(&:name)
    assert_equal 9, wanted.first.plays
    assert_nil wanted.first.artist, "there is no record here to point at"
  end

  test "an artist you own a record by is never wanted" do
    5.times { @gaston.played(@song) }

    assert_empty Report.new(@gaston).wanted
  end

  test "the artists chart names both, and says which is which" do
    @gaston.played(@song)
    heard "Pappo", "Desconfío", times: 9

    top, second = Report.new(@gaston).by_artist

    assert_equal "Pappo", top.name
    assert_nil top.artist
    assert_equal "Almafuerte", second.name
    assert second.artist, "and this one is on the disk, so it can be linked to"
  end

  private

  def heard(who, what, times:)
    gap = @gaston.misses(artist: who, title: what)

    times.times { |at| @gaston.heard_elsewhere(absence: gap, at: at.hours.ago, from: "lastfm") }
  end
end
