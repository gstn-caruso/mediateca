require "test_helper"

class TrackTest < ActiveSupport::TestCase
  setup do
    @charly = Artist.create!(name: "Charly García")
    @album = Album.create!(directory: "/music/piano", title: "Piano Bar", artist: @charly)
  end

  # Which is 933 of the 934 songs on the NAS: the record says who it is by, and
  # every song on it agrees.
  test "a song with no credit of its own is by whoever made the record" do
    track = track_credited_to(nil)

    assert_equal "Charly García", track.artist_name
  end

  # And the 934th. The file credits it to three people, and none of them is the
  # name on the sleeve.
  test "a song the file credits to somebody else is by them" do
    track = track_credited_to("Luis Alberto Spinetta, Pedro Aznar y Charly García")

    assert_equal "Luis Alberto Spinetta, Pedro Aznar y Charly García", track.artist_name
  end

  # An empty tag is a tag nobody filled in, not a song by nobody.
  test "an empty credit is no credit" do
    assert_equal "Charly García", track_credited_to("").artist_name
  end

  # A song with no number is a song nobody numbered — it belongs at the end of
  # the record, not ahead of the first track. SQLite sorts nulls first, so this
  # has to be said out loud.
  test "an unnumbered song comes last, not first" do
    numbered = Track.create!(title: "Demoliendo hoteles", track_no: 1, path: "/music/piano/01.flac", album: @album)
    unnumbered = Track.create!(title: "Hidden", track_no: nil, path: "/music/piano/xx.flac", album: @album)

    assert_equal [ numbered, unnumbered ], @album.tracks.to_a
  end

  private

  def track_credited_to(artist)
    Track.create!(title: "Peluca telefónica", artist:, path: "/music/piano/05.flac", album: @album)
  end
end
