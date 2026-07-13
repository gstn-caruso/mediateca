require "test_helper"

class TracksHelperTest < ActionView::TestCase
  # A playable row addresses the song's audio and its cover, which is the media
  # helper's business.
  include MediaHelper

  # The row a song is pressed from carries the look the app will wear while it
  # plays. The browser is handed the finished properties and applies them: it
  # never opens the cover, never counts a pixel, never decides a colour.
  test "a song carries the look of the record it is on" do
    album = Album.create!(directory: "/music/figure-8", title: "Figure 8", year: 2000,
                          artist: Artist.create!(name: "Elliott Smith"), accent: "#c8102e")
    track = Track.create!(title: "Son of Sam", track_no: 1, disc_no: 1, duration: 186.0,
                          path: "/music/figure-8/01.flac", album:)

    palette = JSON.parse(playable(track, 0)[:palette])

    assert_equal album.palette.accent, palette["--color-accent"]
    assert_equal album.palette.on_accent, palette["--color-on-accent"]
  end

  test "a duration shows in minutes and seconds" do
    assert_equal "2:17", track_duration(136.9)
  end

  test "seconds are padded to two digits" do
    assert_equal "3:05", track_duration(185.0)
  end

  test "a duration over an hour is still counted in minutes" do
    assert_equal "74:30", track_duration(4470.0)
  end

  # beets leaves length as NULL for the odd stray file.
  test "an unknown duration shows as dashes" do
    assert_equal "–:––", track_duration(nil)
  end

  # A whole album's duration reads differently from a single track's: nobody
  # says an album runs 111 minutes.
  test "an album over an hour is measured in hours and minutes" do
    assert_equal "1 h 51 min", album_length(6660)
  end

  test "an album under an hour is measured in minutes" do
    assert_equal "40 min", album_length(2400)
  end

  test "an album of exactly two hours doesn't show extra minutes" do
    assert_equal "2 h", album_length(7200)
  end

  test "an album with no known durations doesn't say how long it runs" do
    assert_nil album_length(0)
    assert_nil album_length(nil)
  end
end
