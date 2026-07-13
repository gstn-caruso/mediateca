require "test_helper"

# What a record's page can tell you that no shop can: how many times *you* have
# put this on. Not the house, and not the world — a play count is a private fact,
# the way the hearts are.
class CountingWhatYouPlayedTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @one = track("Desencuentro", 1)
    @two = track("El Pibe Tigre", 2)
  end

  test "a record nobody has finished says nothing about turns" do
    @gaston.played(@one)

    get album_path(@album)

    assert_no_match "Spun", response.body
  end

  test "a record heard end to end says so" do
    @gaston.played(@one)
    @gaston.played(@two)

    get album_path(@album)

    assert_match "Spun once", response.body
  end

  test "a record heard end to end twice says so" do
    2.times { [ @one, @two ].each { @gaston.played(it) } }

    get album_path(@album)

    assert_match "Spun 2 times", response.body
  end

  test "a song says how many times it was heard" do
    3.times { @gaston.played(@one) }

    get album_path(@album)

    assert_match "3 plays", response.body
  end

  test "a song nobody heard says nothing" do
    get album_path(@album)

    assert_no_match "plays", response.body
  end

  # The count is yours. What somebody else in the house wore out is their
  # business, the way their hearts are.
  test "another listener's turns are not yours" do
    ana = Profile.create!(name: "Ana")
    [ @one, @two ].each { ana.played(it) }

    get album_path(@album)

    assert_no_match "Spun", response.body
    assert_no_match "plays", response.body
  end

  private

  def track(title, number)
    Track.create!(title:, track_no: number, disc_no: 1, duration: 100.0,
                  path: "/music/mundo/#{number}.flac", album: @album)
  end
end
