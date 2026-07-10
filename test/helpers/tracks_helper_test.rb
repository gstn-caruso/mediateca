require "test_helper"

class TracksHelperTest < ActionView::TestCase
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
