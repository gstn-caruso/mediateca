require "test_helper"

# The chart Statistics draws is not a chart of the library — it is a chart of
# what got played, and Last.fm keeps naming artists this house has no record
# by. Leaving them out would put whatever you happen to *own* at the top of a
# chart about what you *play*.
class ShowingTheStatisticsTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/01.flac", album: @album)
  end

  test "the stats say who you actually listen to, owned or not" do
    3.times { |at| @gaston.played(@song, at: (at + 1).hours.ago) }
    gap = @gaston.misses(artist: "Pappo", title: "Desconfío")
    2.times { |at| @gaston.heard_elsewhere(absence: gap, at: (at + 1).hours.ago, from: "lastfm") }

    get statistics_path

    assert_select "h1", text: "Stats"
    assert_match "Pappo", response.body
    assert_match "Almafuerte", response.body
  end
end
