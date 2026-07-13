require "test_helper"

# Mediateca is a library of the records you own, and it could say nothing at all
# about the ones you do not. An import counted them, reported a number, and threw
# the names away — so the app knew about a thousand songs somebody loves and could
# not name one of them.
#
# Now it can. A list brought home from Spotify comes home whole, gaps and all, and
# the library has a shelf for everybody it does not have. Both are drawn grey and
# do nothing: there is no file to play, no sleeve to show, and nowhere to go.
class SeeingWhatYouDoNotHaveTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Elliott Smith")
    album = Album.create!(directory: "/music/either", title: "Either/Or", artist:)
    @angeles = Track.create!(title: "Angeles", duration: 170.0, path: "/music/either/1.flac", album:)
  end

  test "a list keeps the songs you do not have, and says you do not have them" do
    list = @gaston.playlists.create!(name: "Domingo")
    list.add(@angeles)
    list.entries.create!(absence: @gaston.misses(artist: "Pappo", title: "Desconfío"), position: 2)

    get playlist_path(list)

    assert_match "Angeles", response.body
    assert_match "Desconfío", response.body
    assert_match "Not here", response.body
    assert_match "1 song", response.body
    assert_match "1 you don't have", response.body
  end

  # The one that would break the music. The player builds its queue out of the
  # rows it can see and plays the one at the index it is handed — so if a gap were
  # counted, pressing the second song would play the third.
  test "a gap is not a row the player can be handed" do
    list = @gaston.playlists.create!(name: "Domingo")
    list.entries.create!(absence: @gaston.misses(artist: "Pappo", title: "Desconfío"), position: 1)
    list.add(@angeles)

    get playlist_path(list)

    assert_select "[data-player-track]", count: 1
    assert_select "[data-player-index-param='0']"
    assert_select "[data-player-index-param='1']", count: 0
  end

  test "the library shows who it has no record by at all" do
    @gaston.misses(artist: "Pappo", title: "Desconfío")
    @gaston.misses(artist: "Pappo", title: "El Viejo")

    get root_path

    assert_match "Not here yet", response.body
    assert_match "Pappo", response.body
    assert_match "2 songs you don't have", response.body
  end

  # Somebody whose records are on the shelf is not somebody the shelf is missing,
  # even if a song of theirs is. It would be a strange library that listed Elliott
  # Smith under both what it has and what it wants.
  test "an artist you own a record by is never in the shopping list" do
    @gaston.misses(artist: "Elliott Smith", title: "Say Yes")

    get root_path

    assert_no_match "Not here yet", response.body
  end

  test "a listener who is missing nothing is shown no shopping list" do
    get root_path

    assert_no_match "Not here yet", response.body
  end
end
