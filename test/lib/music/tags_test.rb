require "test_helper"

module Music
  # The cases come from the NAS's real tags, read with ffprobe.
  class TagsTest < ActiveSupport::TestCase
    test "reads what the file says about itself" do
      tags = read({
        "ALBUM" => "El perfume de la tempestad",
        "ARTIST" => "Indio Solari",
        "DATE" => "2010",
        "GENRE" => "Rock nacional",
        "TITLE" => "Una rata muerta entre los Geranios",
        "album_artist" => "Indio Solari",
        "track" => "12"
      }, duration: "266.400000")

      assert_equal "Una rata muerta entre los Geranios", tags.title
      assert_equal "Indio Solari", tags.artist
      assert_equal "Indio Solari", tags.album_artist
      assert_equal "El perfume de la tempestad", tags.album
      assert_equal 2010, tags.year
      assert_equal "Rock nacional", tags.genre
      assert_equal 12, tags.track_no
      assert_equal 1, tags.disc_no
      assert_in_delta 266.4, tags.duration
    end

    # ffprobe returns the keys the way whoever tagged the file wrote them:
    # ALBUM, album_artist, Track... They all mean the same thing.
    test "keys are read no matter how they're capitalized" do
      assert_equal "Hypnotize", read({ "album" => "Hypnotize" }).album
      assert_equal "Hypnotize", read({ "ALBUM" => "Hypnotize" }).album
      assert_equal "Hypnotize", read({ "Album" => "Hypnotize" }).album
    end

    # DATE sometimes comes as '2010' and sometimes as '2005-11-22'.
    test "the year is extracted from a full date" do
      assert_equal 2005, read({ "DATE" => "2005-11-22" }).year
      assert_equal 2010, read({ "DATE" => "2010" }).year
      assert_nil read({}).year
    end

    test "the track number can come as 3/12" do
      assert_equal 3, read({ "track" => "3/12" }).track_no
      assert_equal 3, read({ "tracknumber" => "3" }).track_no
      assert_nil read({}).track_no
    end

    test "without a disc number, the disc is one" do
      assert_equal 1, read({}).disc_no
      assert_equal 2, read({ "disc" => "2/3" }).disc_no
      assert_equal 2, read({ "discnumber" => "2" }).disc_no
    end

    # A file with no ALBUMARTIST but with ARTIST: that's the album artist.
    test "without an album artist, the track's artist works" do
      assert_equal "Hermética", read({ "ARTIST" => "Hermética" }).album_artist
    end

    test "without a title, the file name works" do
      tags = read({}, path: "/m/Indio Solari/2010 - X/05 - Satelital.flac")

      assert_equal "05 - Satelital", tags.title
    end

    test "an empty tag is the same as not having it" do
      assert_nil read({ "GENRE" => "", "ALBUM" => "  " }).genre
      assert_nil read({ "GENRE" => "", "ALBUM" => "  " }).album
    end

    private

    def read(tags, duration: "1.0", path: "/m/Artist/1995 - Album/01 - Track.flac")
      probe = VideoBuilders::FakeFfprobe.new(format: { "duration" => duration, "tags" => tags })

      Tags.new(ffprobe: probe).read(path)
    end
  end
end
