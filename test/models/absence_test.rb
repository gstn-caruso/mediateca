require "test_helper"

# The songs you listen to and do not own.
#
# Mediateca is a library of records you have, and it used to be able to say
# nothing at all about the ones you have not — a Spotify import counted them,
# reported a number, and threw the names away. Which meant the app knew about a
# thousand songs you love, and mentioned none of them.
#
# They are not in the library and they are not pretending to be: they cannot be
# played, they have no sleeve, and they are drawn grey. They are the shopping
# list — the shape of the gap between what you listen to and what is on the disk.
class AbsenceTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    @artist = Artist.create!(name: "Elliott Smith")
    @album = Album.create!(directory: "/music/either", title: "Either/Or", artist: @artist)
  end

  test "a song this house does not have is missed by name" do
    missing = @gaston.misses(artist: "Elliott Smith", title: "Say Yes")

    assert_equal "Elliott Smith", missing.artist
    assert_equal "Say Yes", missing.title
  end

  # It is one gap, however many times it turns up: hearted on Spotify and sitting
  # in three playlists is one song you do not own.
  test "the same song missed twice is one gap, not two" do
    @gaston.misses(artist: "Elliott Smith", title: "Say Yes")
    @gaston.misses(artist: "Elliott Smith", title: "Say Yes")

    assert_equal 1, @gaston.absences.count
  end

  # A record that arrives on the disk is a record the shopping list stops asking
  # for. Otherwise it keeps asking for something you went out and bought.
  test "an artist stops being missing once a record of theirs is on the disk" do
    @gaston.misses(artist: "Pappo", title: "Desconfío")
    assert_equal [ "Pappo" ], @gaston.absent_artists.map(&:name)

    Artist.create!(name: "Pappo")

    assert_empty @gaston.absent_artists
  end

  # The library asks who is missing, not what: a shelf is drawn by artist.
  test "the artists this house owns nothing by come back once each" do
    @gaston.misses(artist: "Pappo", title: "Desconfío")
    @gaston.misses(artist: "Pappo", title: "El Viejo")
    @gaston.misses(artist: "Tan Biónica", title: "La Melodía de Dios")

    assert_equal [ "Pappo", "Tan Biónica" ], @gaston.absent_artists.map(&:name).sort
  end

  # An artist you own a record by is not missing, even if some of their songs are.
  # The shelf already has them; it is a song that is short, not a person.
  test "an artist already on the shelf is not a missing artist" do
    Track.create!(title: "Angeles", duration: 170.0, path: "/music/either/angeles.flac", album: @album)

    @gaston.misses(artist: "Elliott Smith", title: "Say Yes")

    assert_empty @gaston.absent_artists
  end

  test "what one listener misses, another does not" do
    @gaston.misses(artist: "Pappo", title: "Desconfío")

    assert_empty Profile.create!(name: "Ana").absent_artists
  end
end
