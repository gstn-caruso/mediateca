require "test_helper"

# The rail says, in its own comments, that a home library has no recommender and
# needs none: what comes after a record is more of whoever you are already on, and
# once they run out, anything else on the disk — drawn at random, "because nothing
# here is more like Piazzolla than anything else".
#
# That last sentence was true only because nothing in the house knew otherwise.
# Last.fm does. So the random draw stays exactly where it was — as the answer when
# nobody knows — and when Last.fm does know, the rail offers kin instead: bands it
# says are like the one playing, and only the ones whose records are on this disk,
# because those are the only ones it can actually put on.
class SuggestingKinTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    @almafuerte = artist("Almafuerte")
    @hermetica = artist("Hermética")
    @piazzolla = artist("Astor Piazzolla")

    @playing = song(@almafuerte, "Mundo Guanaco", "Desencuentro")
    @kindred = song(@hermetica, "Ácido Argentino", "Memoria de Siglos")
    @stranger = song(@piazzolla, "Adiós Nonino", "Adiós Nonino")
  end

  test "with nobody left of the artist, the rail offers who Last.fm says is kin" do
    kin_of @almafuerte, @hermetica, match: 0.9

    assert_equal [ @kindred ], suggestions.tracks
    assert_equal "Like Almafuerte", suggestions.heading
  end

  # The old promise, kept. When Last.fm has never heard of the band — or has not
  # been asked — the draw is still the whole library, at random.
  test "an artist nobody is kin to still falls back to the library" do
    assert_includes suggestions.tracks, @stranger
    assert_equal "From your library", suggestions.heading
  end

  # A band Last.fm calls kin whose records are not on this disk is not an offer.
  # The rail can only play what is here.
  test "kin whose records this house does not own are not offered" do
    Kinship.create!(artist: @almafuerte, kin: artist("A Band We Own Nothing By"), match: 0.99)

    assert_equal "From your library", suggestions.heading
  end

  # The artist still playing comes first. Kinship is what happens *after* they run
  # out — it does not get to push their own songs off the rail.
  test "more of the artist you are on still beats their kin" do
    another = song(@almafuerte, "Mundo Guanaco", "El Pibe Tigre")
    kin_of @almafuerte, @hermetica, match: 0.9

    assert_equal [ another ], suggestions.tracks
    assert_equal "More from Almafuerte", suggestions.heading
  end

  # Hiding somebody means never being offered them, and Last.fm calling them kin
  # is not a reason to break that.
  test "kin you have hidden are still hidden" do
    kin_of @almafuerte, @hermetica, match: 0.9
    @gaston.hide(@hermetica)

    assert_not_includes suggestions.tracks, @kindred
  end

  # And the highlighted keep their couple of slots, whoever the kin are.
  test "an artist you highlighted is offered among the kin" do
    kin_of @almafuerte, @hermetica, match: 0.9
    @gaston.highlight(@piazzolla)

    assert_includes suggestions.tracks, @stranger
  end

  private

  def suggestions
    Suggestions.new(track: @playing, profile: @gaston.reload)
  end

  def kin_of(artist, kin, match:)
    Kinship.create!(artist:, kin:, match:)
  end

  def artist(name) = Artist.create!(name:)

  def song(artist, record, title)
    album = Album.find_or_create_by!(directory: "/music/#{record}", title: record, artist:)

    Track.create!(title:, duration: 200.0, path: "/music/#{record}/#{title}.flac", album:)
  end
end
