require "test_helper"

# One library, three ways to look at it: whoever made the music, the records
# themselves, and the lists somebody put together out of them. The tab overhead
# names which of the three you are looking at, which is why no row underneath it
# has to name itself.
class ShowingTheLibraryTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(directory: "/music/mundo-guanaco", title: "Mundo Guanaco", year: 1995, artist: @artist)
    @track = Track.create!(title: "Desencuentro", path: "/music/mundo-guanaco/01.flac", album: @album)
    @playlist = @gaston.playlists.create!(name: "Asado")
  end

  test "the rail holds the artists, the records, and the lists" do
    get root_path

    assert_select "nav a[href=?]", artist_path(@artist)
    assert_select "nav a[href=?]", album_path(@album)
    assert_select "nav a[href=?]", playlist_path(@playlist)
    assert_select "nav a[href=?]", likes_path
  end

  # The records were only ever a click deeper than the artist who made them.
  test "the rail can be turned to the records themselves" do
    get root_path

    assert_select "nav [role=tablist]" do
      assert_select "[role=tab]", 3
    end
  end

  test "the library page turns the same three ways the rail does" do
    get root_path

    assert_select "main [role=tablist] [role=tab]", 3
  end

  # A row that says "Artist · 2 albums" is spending its one line of small print
  # on a word the tab above it has already said. The line is worth more than
  # that: it can say something only this row knows.
  test "no row spells out what kind of thing it is" do
    get root_path

    assert_no_match(/Artist ·/, response.body)
    assert_no_match(/Playlist ·/, response.body)
  end

  test "an artist's row says how many records are behind it" do
    get root_path

    assert_select "nav a[href=?]", artist_path(@artist), text: /1 album/
  end

  test "a record's row says who made it and when" do
    get root_path

    assert_select "nav a[href=?]", album_path(@album), text: /Almafuerte · 1995/
  end

  test "the hearts count the songs they hold, rather than announcing they are a playlist" do
    @gaston.like(@track)

    get root_path

    assert_select "nav a[href=?]", likes_path, text: /1 song/
  end
end
