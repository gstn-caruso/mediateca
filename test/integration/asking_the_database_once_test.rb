require "test_helper"

# A page's cost should follow what it *shows*, not how much of it there is.
#
# The rule these tests hold every page to: growing the library must not grow the
# number of questions the page asks. A page that asks one question per row is
# fine at a hundred rows and unusable at ten thousand, and it never announces
# itself — it just gets slower every time somebody adds a record.
#
# So each test renders a page twice, once small and once ten times bigger, and
# demands the same number of queries. Counting exactly is brittle; counting the
# *slope* is the property we actually care about.
class AskingTheDatabaseOnceTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    @artist = Artist.create!(name: "Almafuerte")
    @album = album_by(@artist, "Mundo Guanaco")
    @track = track_on(@album, "Desencuentro")
  end

  # The sidebar renders on every page there is, so an N+1 in it is an N+1
  # everywhere: the album page, the search, the hearts, all of them.
  test "the sidebar does not ask one question per artist" do
    assert_flat -> { get root_path } do
      9.times { |n| album_by(Artist.create!(name: "Artist #{n}"), "Album #{n}") }
    end
  end

  # The rail holds the records themselves now, and each row names who made it.
  test "the sidebar does not ask one question per record on the shelf" do
    assert_flat -> { get root_path } do
      9.times { |n| album_by(@artist, "Album #{n}") }
    end
  end

  test "the sidebar does not ask one question per playlist" do
    @gaston.playlists.create!(name: "Asado")

    assert_flat -> { get root_path } do
      9.times { |n| @gaston.playlists.create!(name: "Playlist #{n}").add(@track) }
    end
  end

  # The heart on each row used to ask the database whether that row was liked.
  test "an album does not ask one question per song" do
    assert_flat -> { get album_path(@album) } do
      9.times { |n| track_on(@album, "Song #{n}") }
    end
  end

  # Every row walks entry → track → album → artist to name who is singing.
  test "a playlist does not ask one question per song on it" do
    playlist = @gaston.playlists.create!(name: "Asado")
    playlist.add(@track)

    assert_flat -> { get playlist_path(playlist) } do
      9.times { |n| playlist.add(track_on(@album, "Song #{n}")) }
    end
  end

  test "the liked songs do not ask one question per heart" do
    @gaston.like(@track)

    assert_flat -> { get likes_path } do
      9.times { |n| @gaston.like(track_on(@album, "Song #{n}")) }
    end
  end

  test "a search does not ask one question per result" do
    track_on(@album, "Song")

    assert_flat -> { get search_path(q: "Song") } do
      9.times { |n| track_on(@album, "Song #{n}") }
    end
  end

  private

  # Render the page, grow the library, render it again: the same number of
  # questions, or the page asks one per row.
  def assert_flat(page, &growth)
    before = queries_while(&page)
    growth.call
    after = queries_while(&page)

    assert_equal before, after,
      "the page asked #{before} queries with one row and #{after} with ten: it asks one per row"
  end

  def queries_while
    counted = 0
    count = ->(_name, _start, _finish, _id, payload) do
      counted += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ])
    end

    ActiveSupport::Notifications.subscribed(count, "sql.active_record") { yield }

    counted
  end

  def album_by(artist, title)
    Album.create!(directory: "/music/#{title.parameterize}", title:, artist:)
  end

  def track_on(album, title)
    Track.create!(title:, path: "/music/#{album.title.parameterize}/#{title.parameterize}.flac", album:)
  end
end
