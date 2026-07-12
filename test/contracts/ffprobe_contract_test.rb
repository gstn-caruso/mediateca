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

  # The same second and a half of noise — quiet, then loud — encoded twice: once
  # holding 128 kbps, once letting LAME spend what each half was worth. Nothing
  # in what ffprobe *says* about them tells the two apart; only their frames do.
  CONSTANT = Rails.root.join("test/fixtures/audio/constant.mp3").to_s
  VARIABLE = Rails.root.join("test/fixtures/audio/variable.mp3").to_s

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

  # The assumption the whole badge rests on, and the only one no fake can check:
  # that ffprobe still hands back a size per frame, and that a held bitrate still
  # looks held. If either stops being true, every MP3 in the library would start
  # claiming the wrong mode — quietly, and forever.
  test "ffprobe still counts frames, and a held bitrate still reads as held" do
    assert_equal "constant", Music::Tags.new.read(CONSTANT).audio.bit_rate_mode
    assert_equal "variable", Music::Tags.new.read(VARIABLE).audio.bit_rate_mode
  end

  # Not a hair's breadth apart: the two are told apart by a byte of padding
  # against hundreds. If that margin ever closed, the test above could still pass
  # by luck — this one says how much room it had.
  test "the two are not close" do
    assert_operator spread_of(CONSTANT), :<=, Music::BitRateMode::PADDING
    assert_operator spread_of(VARIABLE), :>, 100
  end

  # A lossless file is never asked how it spends its bits, because the question
  # is meaningless: FLAC frames swell and shrink with the music and mean nothing
  # by it. Left to answer, this file would call itself variable.
  test "a lossless file is not asked, and would answer wrong if it were" do
    assert_nil Music::Tags.new.read(FLAC).audio.bit_rate_mode
    assert_operator spread_of(FLAC), :>, Music::BitRateMode::PADDING
  end

  test "a file that isn't audio says so rather than importing as a song" do
    assert_raises(Ffprobe::Unreadable) { Ffprobe.new.describe(__FILE__) }
  end

  private

  def spread_of(path)
    sizes = Ffprobe.new.frame_sizes(path)

    sizes.max - sizes.min
  end

  def ffprobe_installed?
    system(Rails.configuration.x.ffprobe, "-version", out: File::NULL, err: File::NULL)
  end
end
