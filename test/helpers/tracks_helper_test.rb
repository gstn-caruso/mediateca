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

  # A lossless file is measured by its depth and sample rate: the badge every
  # FLAC in the library wears.
  test "a lossless track's badge is its codec, depth and sample rate" do
    assert_equal "FLAC · 16/44.1", track_quality(track(codec: "flac", bit_depth: 16, sample_rate: 44100))
    assert_equal "FLAC · 24/96", track_quality(track(codec: "flac", bit_depth: 24, sample_rate: 96000))
    assert_equal "FLAC · 24/88.2", track_quality(track(codec: "flac", bit_depth: 24, sample_rate: 88200))
  end

  # A compressed file has no fixed depth, so its badge is the bitrate it settled
  # on, in kilobits.
  test "a lossy track's badge is its codec and bitrate" do
    assert_equal "MP3 · 320", track_quality(track(codec: "mp3", bit_rate: 320000))
    assert_equal "AAC · 256", track_quality(track(codec: "aac", bit_rate: 256000))
  end

  # Scanned before we recorded encodings: no badge rather than a blank one.
  test "a track with no known codec has no badge" do
    assert_nil track_quality(track(codec: nil))
  end

  # The tooltip spells out everything measured, bitrate and all.
  test "the detailed quality names every measure it has" do
    assert_equal "FLAC · 16-bit · 44.1 kHz · 1007 kbps",
      track_quality_detail(track(codec: "flac", bit_depth: 16, sample_rate: 44100, bit_rate: 1006840))
  end

  private

  def track(**attributes)
    Track.new(**attributes)
  end
end
