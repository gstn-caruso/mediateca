require "test_helper"

class SuggestionsTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    @piazzolla = Artist.create!(name: "Astor Piazzolla")
    @regina = Album.create!(directory: "/music/regina", title: "En el Regina", artist: @piazzolla)
    @playing = track("La evasion", @regina, 1)
  end

  # Nothing to offer is a real answer: a library of one song has no second one.
  test "a library with nothing else in it suggests nothing" do
    suggestions = suggesting

    assert_empty suggestions.tracks
    assert_empty suggestions.heading
  end

  test "the rest of the artist is what comes next" do
    libertango = track("Libertango", @regina, 2)
    nonino = track("Adios Nonino", @regina, 3)

    assert_equal [ libertango, nonino ], suggesting.tracks
  end

  test "the song that is playing is not suggested back" do
    track("Libertango", @regina, 2)

    assert_not_includes suggesting.tracks, @playing
  end

  # A suggestion is for what is *not* coming: whatever the queue already holds
  # would be offering somebody a song they are about to hear anyway.
  test "what is already in the queue is not suggested" do
    libertango = track("Libertango", @regina, 2)
    nonino = track("Adios Nonino", @regina, 3)

    suggestions = suggesting(queued: [ @playing.id, libertango.id ])

    assert_equal [ nonino ], suggestions.tracks
  end

  # The rail is a rail, not a discography.
  test "a handful, not the whole artist" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }

    assert_equal Suggestions::FEW, suggesting.tracks.size
  end

  test "the heading names the artist you are listening to" do
    track("Libertango", @regina, 2)

    assert_equal "More from Astor Piazzolla", suggesting.heading
  end

  # When the artist runs out, the library is still there. It is a weaker offer,
  # and it says so rather than pretending to be more Piazzolla.
  test "when the artist runs out, the library answers instead" do
    desencuentro = track("Desencuentro", almafuerte_record, 1)

    suggestions = suggesting

    assert_equal [ desencuentro ], suggestions.tracks
    assert_equal "From your library", suggestions.heading
  end

  # --- Whoever you have hidden ------------------------------------------------

  # The whole promise of hiding somebody: nothing offers them, ever. Not the
  # rest of the rail, and not the library when the rail runs dry.
  test "a hidden artist is never offered" do
    track("Desencuentro", almafuerte_record, 1)
    @gaston.hide(almafuerte)

    assert_empty suggesting.tracks
  end

  # Even while you are playing them — which you can, by searching them out by
  # hand. Playing somebody once is not asking to be handed more of them.
  test "not even the artist playing, if you have hidden them" do
    track("Libertango", @regina, 2)
    @gaston.hide(@piazzolla)

    assert_empty suggesting.tracks
  end

  test "one listener's hiding does not reach another's rail" do
    desencuentro = track("Desencuentro", almafuerte_record, 1)
    @gaston.hide(almafuerte)

    ana = Profile.create!(name: "Ana")

    assert_equal [ desencuentro ], suggesting(profile: ana).tracks
  end

  # --- Whoever you have highlighted -------------------------------------------

  # An artist you highlighted gets in whatever else is playing — that is what
  # highlighting them was for. The rail still leads with the record you are on;
  # a couple of its slots are given away.
  test "a highlighted artist takes a couple of slots, even when the artist playing has more to give" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }
    desencuentro = track("Desencuentro", almafuerte_record, 1)
    @gaston.highlight(almafuerte)

    tracks = suggesting.tracks

    assert_includes tracks, desencuentro
    assert_equal Suggestions::FEW, tracks.size
    assert_equal @piazzolla, tracks.first.album.artist
  end

  # "Their featured songs" is not a list anybody keeps here, and does not need to
  # be: the songs of theirs you go back to are the ones you have played, and the
  # database has been writing that down all along. More songs than slots, so the
  # choosing means something.
  test "the slots go to the highlighted artist's songs you play most" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }

    guanaco = almafuerte_record
    loved = track("Desencuentro", guanaco, 1)
    played_once = track("Zamba de Anta", guanaco, 2)
    ignored = track("Se Vuelve Loco", guanaco, 3)
    also_ignored = track("Vientos de Cambio", guanaco, 4)

    3.times { @gaston.played(loved) }
    @gaston.played(played_once)
    @gaston.highlight(almafuerte)

    tracks = suggesting.tracks

    assert_equal [ loved, played_once ], tracks.last(Suggestions::A_COUPLE)
    assert_not_includes tracks, ignored
    assert_not_includes tracks, also_ignored
  end

  # An artist you highlighted and never listened to still has something to
  # offer: any of them, then. Nothing to go on is not a reason to offer nothing.
  test "a highlighted artist you have never played still gets in" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }
    desencuentro = track("Desencuentro", almafuerte_record, 1)

    @gaston.highlight(almafuerte)

    assert_includes suggesting.tracks, desencuentro
  end

  # A highlighted artist you are already listening to needs no help getting in:
  # the rail is already theirs, and spending a slot on them would only mean one
  # song of theirs pushing another of theirs out.
  test "highlighting the artist playing does not cost them slots" do
    10.times { |n| track("Tango #{n}", @regina, n + 2) }
    @gaston.highlight(@piazzolla)

    artists = suggesting.tracks.map { it.album.artist }

    assert_equal [ @piazzolla ] * Suggestions::FEW, artists
  end

  # And when the artist runs out and the library answers, a highlighted artist
  # is heavier in the draw rather than merely present in it. Two songs, one
  # apiece: an even draw would lead with each about half the time, and a draw
  # weighted three to one leads with the highlighted one about three times in
  # four. The margin here is far too wide to come up by chance.
  test "a highlighted artist is heavier in the library's draw" do
    track("Desencuentro", almafuerte_record, 1)

    charly = Artist.create!(name: "Charly García")
    clics = Album.create!(directory: "/music/clics", title: "Clics Modernos", artist: charly)
    nos_siguen = track("Nos siguen pegando abajo", clics, 1)

    @gaston.highlight(charly)

    led = 200.times.count { suggesting.tracks.first == nos_siguen }

    assert_operator led, :>, 110, "the highlighted artist led #{led} draws of 200; an even draw leads about 100"
  end

  private

  def suggesting(profile: @gaston, queued: [])
    Suggestions.new(track: @playing, profile:, queued:)
  end

  def almafuerte
    @almafuerte ||= Artist.create!(name: "Almafuerte")
  end

  def almafuerte_record
    @almafuerte_record ||= Album.create!(directory: "/music/guanaco", title: "Mundo Guanaco", artist: almafuerte)
  end

  def track(title, album, number)
    Track.create!(title:, track_no: number, disc_no: 1, path: "#{album.directory}/#{number}.flac", album:)
  end
end
