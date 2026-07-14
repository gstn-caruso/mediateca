require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "a profile is someone with a name" do
    assert Profile.new(name: "Gastón").valid?
  end

  test "a nameless profile is nobody" do
    refute Profile.new(name: "").valid?
    refute Profile.new(name: "   ").valid?
  end

  # Without a password, the name is the only thing telling two listeners apart.
  test "two listeners cannot share a name" do
    Profile.create!(name: "Gastón")

    refute Profile.new(name: "Gastón").valid?
  end

  # A profile that moved in the grid would be a profile you click by mistake.
  test "profiles keep the order they were created in" do
    [ "Zoe", "Ana", "Beto" ].each { |name| Profile.create!(name:) }

    assert_equal [ "Zoe", "Ana", "Beto" ], Profile.ordered.map(&:name)
  end

  # Where a listener stands on an artist. Most artists get no say at all, and
  # that silence is the ordinary case — a row exists only where somebody
  # bothered to have an opinion.
  test "an artist nobody has an opinion about is neither hidden nor highlighted" do
    refute gaston.hides?(piazzolla)
    refute gaston.highlights?(piazzolla)
  end

  test "an artist can be hidden, and shown again" do
    gaston.hide(piazzolla)
    assert gaston.hides?(piazzolla)

    gaston.unhide(piazzolla)
    refute gaston.hides?(piazzolla)
  end

  test "an artist can be highlighted, and let go again" do
    gaston.highlight(piazzolla)
    assert gaston.highlights?(piazzolla)

    gaston.unhighlight(piazzolla)
    refute gaston.highlights?(piazzolla)
  end

  # The two are opposites, not a pair of switches: to hide somebody you were
  # pushing forward is to stop pushing them forward.
  test "hiding an artist takes back the highlight" do
    gaston.highlight(piazzolla)

    gaston.hide(piazzolla)

    assert gaston.hides?(piazzolla)
    refute gaston.highlights?(piazzolla)
  end

  test "highlighting an artist brings it out of hiding" do
    gaston.hide(piazzolla)

    gaston.highlight(piazzolla)

    assert gaston.highlights?(piazzolla)
    refute gaston.hides?(piazzolla)
  end

  # Pressed twice — a double click, or the phone and the tablet at once — both
  # presses find nothing and both insert. The unique index is what says no, the
  # way it does for a heart.
  test "hiding an artist twice hides it once" do
    gaston.hide(piazzolla)
    gaston.hide(piazzolla)

    assert_equal 1, gaston.standings.count
  end

  # This is the whole point of it being per listener: the house does not agree
  # about music, and nobody has to.
  test "one listener hiding an artist does not hide it for anybody else" do
    gaston.hide(piazzolla)

    refute Profile.create!(name: "Ana").hides?(piazzolla)
  end

  test "a hidden artist's records leave what you recently played" do
    almafuerte = Artist.create!(name: "Almafuerte")
    guanaco = Album.create!(directory: "/music/guanaco", title: "Mundo Guanaco", artist: almafuerte)
    desencuentro = Track.create!(title: "Desencuentro", path: "/music/guanaco/01.flac", album: guanaco)
    gaston.played(desencuentro)

    gaston.hide(almafuerte)

    assert_empty gaston.recently_played_albums
  end

  private

  def gaston
    @gaston ||= Profile.create!(name: "Gastón")
  end

  def piazzolla
    @piazzolla ||= Artist.create!(name: "Astor Piazzolla")
  end
end
