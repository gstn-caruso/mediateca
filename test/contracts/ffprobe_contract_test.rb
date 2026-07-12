require "test_helper"

# The only test that runs the real ffprobe.
#
# Every other test reads tags through a description we wrote ourselves, so the
# suite needs no binary. What none of them can verify is the one thing this
# does: that ffprobe still describes a FLAC the way Music::Tags assumes it
# does — the keys it names, the shapes it puts in them.
#
# Those assumptions are not obvious, and each one is a line in Tags:
# ffprobe hands back TITLE and album_artist and track in whatever case the
# tagger typed, a DATE that may be a whole date, and a track number that may
# carry its total. Change ffprobe and any of them could quietly stop being true;
# the scanner would keep running and the library would come back nameless.
#
# Skipped where ffprobe isn't installed — except under REQUIRE_FFPROBE, which is
# how CI runs it, so it can never come up green without having actually run.
class FfprobeContractTest < ActiveSupport::TestCase
  # A second of silence, tagged the way the NAS's files are tagged.
  FLAC = Rails.root.join("test/fixtures/audio/tagged.flac").to_s

  setup do
    next if ffprobe_installed?

    # Skipping silently where this is supposed to run would be worse than not
    # having it: the suite would go green without verifying anything.
    flunk "ffprobe is not installed and REQUIRE_FFPROBE demands it" if ENV["REQUIRE_FFPROBE"].present?

    skip "ffprobe is not installed"
  end

  test "ffprobe still names the tags the way Music::Tags reads them" do
    tags = Music::Tags.new.read(FLAC)

    assert_equal "Desencuentro", tags.title
    assert_equal "Almafuerte", tags.artist
    assert_equal "Almafuerte", tags.album_artist
    assert_equal "Mundo Guanaco", tags.album
  end

  test "a whole date still arrives where the year is read from" do
    assert_equal 1995, Music::Tags.new.read(FLAC).year
  end

  test "a track number still arrives carrying its total" do
    tags = Music::Tags.new.read(FLAC)

    assert_equal 1, tags.track_no
    assert_equal 1, tags.disc_no
  end

  test "ffprobe still measures the encoding the quality badge is built from" do
    audio = Music::Tags.new.read(FLAC).audio

    assert_equal "flac", audio.codec
    assert_equal 16, audio.bit_depth
    assert_equal 44_100, audio.sample_rate
  end

  test "the length ffprobe reports is the length we play" do
    assert_in_delta 1.0, Music::Tags.new.read(FLAC).duration, 0.05
  end

  test "a file that isn't audio says so rather than importing as a song" do
    assert_raises(Ffprobe::Unreadable) { Ffprobe.new.describe(__FILE__) }
  end

  private

  def ffprobe_installed?
    system(Rails.configuration.x.ffprobe, "-version", out: File::NULL, err: File::NULL)
  end
end
