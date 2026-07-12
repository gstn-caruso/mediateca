require "test_helper"

class SuggestionsTest < ActiveSupport::TestCase
  setup do
    @piazzolla = Artist.create!(name: "Astor Piazzolla")
    @regina = Album.create!(directory: "/music/regina", title: "En el Regina", artist: @piazzolla)
    @playing = track("La evasion", @regina, 1)
  end

  # Nothing to offer is a real answer: a library of one song has no second one.
  test "a library with nothing else in it suggests nothing" do
    suggestions = Suggestions.new(track: @playing)

    assert_empty suggestions.tracks
    assert_empty suggestions.heading
  end

  test "the rest of the artist is what comes next" do
    libertango = track("Libertango", @regina, 2)
    nonino = track("Adios Nonino", @regina, 3)

    assert_equal [ libertango, nonino ], Suggestions.new(track: @playing).tracks
  end

  test "the song that is playing is not suggested back" do
    track("Libertango", @regina, 2)

    assert_not_includes Suggestions.new(track: @playing).tracks, @playing
  end

  # A suggestion is for what is *not* coming: whatever the queue already holds
  # would be offering somebody a song they are about to hear anyway.
  test "what is already in the queue is not suggested" do
    libertango = track("Libertango", @regina, 2)
    nonino = track("Adios Nonino", @regina, 3)

    suggestions = Suggestions.new(track: @playing, queued: [ @playing.id, libertango.id ])

    assert_equal [ nonino ], suggestions.tracks
  end

  # The rail is a rail, not a discography.
  test "a handful, not the whole artist" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }

    assert_equal Suggestions::FEW, Suggestions.new(track: @playing).tracks.size
  end

  test "the heading names the artist you are listening to" do
    track("Libertango", @regina, 2)

    assert_equal "More from Astor Piazzolla", Suggestions.new(track: @playing).heading
  end

  # When the artist runs out, the library is still there. It is a weaker offer,
  # and it says so rather than pretending to be more Piazzolla.
  test "when the artist runs out, the library answers instead" do
    almafuerte = Artist.create!(name: "Almafuerte")
    guanaco = Album.create!(directory: "/music/guanaco", title: "Mundo Guanaco", artist: almafuerte)
    desencuentro = track("Desencuentro", guanaco, 1)

    suggestions = Suggestions.new(track: @playing)

    assert_equal [ desencuentro ], suggestions.tracks
    assert_equal "From your library", suggestions.heading
  end

  private

  def track(title, album, number)
    Track.create!(title:, track_no: number, disc_no: 1, path: "#{album.directory}/#{number}.flac", album:)
  end
end
