require "test_helper"

class PlayTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @mundo = album("Mundo Guanaco", "/music/mundo")
    @pesos = album("Pesos Pesados", "/music/pesos")
  end

  test "nothing has been played yet" do
    assert_empty @gaston.recently_played_albums
  end

  test "an album played once shows up" do
    @gaston.played(track_of(@mundo))

    assert_equal [ @mundo ], @gaston.recently_played_albums
  end

  # The row is "recently played albums", not "recently played songs": four songs
  # off one record are one record.
  test "an album played four times shows up once" do
    4.times { @gaston.played(track_of(@mundo)) }

    assert_equal [ @mundo ], @gaston.recently_played_albums
  end

  test "the album played last comes first" do
    @gaston.played(track_of(@mundo))
    @gaston.played(track_of(@pesos))

    assert_equal [ @pesos, @mundo ], @gaston.recently_played_albums
  end

  # Coming back to a record moves it to the front, ahead of what you heard since.
  test "playing an old album again brings it back to the front" do
    @gaston.played(track_of(@mundo))
    @gaston.played(track_of(@pesos))
    @gaston.played(track_of(@mundo))

    assert_equal [ @mundo, @pesos ], @gaston.recently_played_albums
  end

  test "what one profile played, another has not" do
    @gaston.played(track_of(@mundo))

    assert_empty Profile.create!(name: "Ana").recently_played_albums
  end

  private

  def album(title, directory)
    Album.create!(directory:, title:, artist: Artist.first)
  end

  def track_of(album)
    Track.create!(title: "Song #{Track.count + 1}", path: "#{album.directory}/#{Track.count + 1}.flac", album:)
  end
end
