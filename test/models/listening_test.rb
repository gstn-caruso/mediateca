require "test_helper"

# Three lists a hundred thousand scrobbles are owed. Two of them point at music
# nobody could sell you — which is exactly why no shop has ever made them.
class ListeningTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @loved = song("Desencuentro")
    @forgotten = song("El Pibe Tigre")
  end

  test "a listener who has heard nothing gets no lists" do
    assert_empty Listening.new(@gaston).make_the_lists
  end

  test "what you play most, of what you have" do
    3.times { @gaston.played(@loved) }

    Listening.new(@gaston).make_the_lists

    assert_equal [ @loved ], list("On repeat").tracks.to_a
  end

  # The useful one. A playlist that plays nothing, and it is exactly what to go
  # and find.
  test "what you play most and cannot play here" do
    gap = @gaston.misses(artist: "Pappo", title: "Desconfío")
    9.times { |at| @gaston.heard_elsewhere(absence: gap, at: at.hours.ago, from: "lastfm") }

    Listening.new(@gaston).make_the_lists

    entries = list("Not on the disk").entries.ordered

    assert_equal [ "Desconfío" ], entries.map(&:title)
    assert_not_predicate entries.first, :playable?
  end

  # Nothing that sells music has any reason to build this: it points you at what
  # you already own.
  test "songs you own, played hard once, and not gone back to in a year" do
    4.times { |at| @gaston.heard_elsewhere(track: @forgotten, at: (2.years.ago + at.days), from: "lastfm") }
    2.times { @gaston.played(@loved) }

    Listening.new(@gaston).make_the_lists

    assert_equal [ @forgotten ], list("You've forgotten these").tracks.to_a
  end

  # An answer that keeps yesterday's songs in it is a stale answer wearing a fresh
  # name.
  test "the lists are rebuilt, not added to" do
    3.times { @gaston.played(@loved) }
    Listening.new(@gaston).make_the_lists

    Listening.new(@gaston).make_the_lists

    assert_equal 1, list("On repeat").entries.count
  end

  private

  def list(name) = @gaston.playlists.find_by!(name:)

  def song(title)
    Track.create!(title:, duration: 200.0, path: "/music/mundo/#{title}.flac", album: @album)
  end
end
