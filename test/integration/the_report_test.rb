require "test_helper"

# The report. Not "you played 127,231 songs" — every service says that. The one
# fact only a library can hand you is the other one: how much of what you love it
# hasn't got.
class TheReportTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @song = Track.create!(title: "Desencuentro", duration: 137.0, path: "/music/mundo/01.flac", album: @album)

    @gaston.played(@song, at: 1.hour.ago)
    @gaston.heard_elsewhere(absence: @gaston.misses(artist: "Pappo", title: "Desconfío"), at: 1.hour.ago, from: "lastfm")
  end

  test "the report leads with what this disk hasn't got" do
    get report_path

    assert_select "h1", text: /aren't on this disk/
    assert_match "Your years", response.body
    assert_match "Your hours", response.body
    assert_match "Who you listen to", response.body
    assert_match "What isn't here yet", response.body
  end
end
