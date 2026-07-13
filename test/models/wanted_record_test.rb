require "test_helper"

# The only ranking in music that has ever been honest, and a library is the only
# thing that could have kept it: not what is popular, not what somebody is paid to
# put in front of you — what *you* have worn out, on somebody else's machine, for
# years, and have never had a copy of.
class WantedRecordTest < ActiveSupport::TestCase
  setup do
    Lastfm.api = @lastfm = FakeTopAlbums.new
    Qbittorrent.api = @qbit = FakeQbittorrent.new
    @gaston = Profile.create!(name: "Gastón")
    @gaston.scrobbles_to(username: "ekvintroj", session_key: "k")
  end

  test "a record you play and do not own is wanted" do
    @lastfm.tops("Nirvana" => [ "In Utero", 793 ])

    WantedRecord.refresh_from(@gaston)

    assert_equal "In Utero", WantedRecord.sole.title
    assert_equal 793, WantedRecord.sole.plays
  end

  test "a record already on the shelf is not wanted" do
    shelve("Nirvana", "In Utero")
    @lastfm.tops("Nirvana" => [ "In Utero", 793 ])

    WantedRecord.refresh_from(@gaston)

    assert_predicate WantedRecord.all, :empty?
  end

  # Case is nothing, accents are nothing — the same blunt match as everywhere else.
  test "the shelf is subtracted however it is spelled" do
    shelve("Café Tacvba", "Re")
    @lastfm.tops("CAFE TACVBA" => [ "re", 400 ])

    WantedRecord.refresh_from(@gaston)

    assert_predicate WantedRecord.all, :empty?
  end

  # A record you have played twice is a record you heard twice, not one you want.
  test "a record you have barely played is not wanted" do
    @lastfm.tops("Nirvana" => [ "In Utero", 3 ])

    WantedRecord.refresh_from(@gaston)

    assert_predicate WantedRecord.all, :empty?
  end

  test "asking again refreshes the tally rather than wanting it twice" do
    @lastfm.tops("Nirvana" => [ "In Utero", 793 ])
    WantedRecord.refresh_from(@gaston)

    @lastfm.tops("Nirvana" => [ "In Utero", 900 ])
    WantedRecord.refresh_from(@gaston)

    assert_equal 1, WantedRecord.count
    assert_equal 900, WantedRecord.sole.plays
  end

  # Last.fm, asked for somebody's top records.
  class FakeTopAlbums < FakeLastfm
    def tops(records)
      @tops = records
      self
    end

    def top_albums(user:, limit: 200)
      @tops.map { |artist, (album, plays)| { artist:, album:, plays: } }
    end
  end

  private

  def shelve(who, what)
    Album.create!(directory: "/music/#{what}", title: what, artist: Artist.create!(name: who))
  end
end
