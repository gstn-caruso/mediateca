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

    # A lossless file reports its codec, its bit depth and its sample rate: the
    # three numbers that say "16-bit / 44.1 kHz FLAC".
    test "reads the audio stream's codec, depth, sample rate and bitrate" do
      audio = read({}, streams: [ {
        "codec_type" => "audio", "codec_name" => "flac", "sample_rate" => "44100",
        "bits_per_raw_sample" => "16", "bit_rate" => "1006840"
      } ]).audio

      assert_equal "flac", audio.codec
      assert_equal 16, audio.bit_depth
      assert_equal 44100, audio.sample_rate
      assert_equal 1006840, audio.bit_rate
    end

    # A lossy stream has no fixed depth — bits_per_sample is 0 — so what it can
    # report is its bitrate.
    test "a lossy stream reports its bitrate and no bit depth" do
      audio = read({}, streams: [ {
        "codec_type" => "audio", "codec_name" => "mp3", "sample_rate" => "44100",
        "sample_fmt" => "fltp", "bits_per_sample" => 0, "bit_rate" => "320000"
      } ]).audio

      assert_equal "mp3", audio.codec
      assert_nil audio.bit_depth
      assert_equal 320000, audio.bit_rate
    end

    # FLAC often prints its bit rate only on the format, not on the stream.
    test "the bit rate falls back to the format when the stream omits it" do
      audio = read({},
        streams: [ { "codec_type" => "audio", "codec_name" => "flac", "bits_per_raw_sample" => "16" } ],
        format: { "bit_rate" => "900000" }).audio

      assert_equal 900000, audio.bit_rate
    end

    test "without an audio stream there is nothing to say about the audio" do
      assert_nil read({}).audio
    end

    private

    def read(tags, duration: "1.0", path: "/m/Artist/1995 - Album/01 - Track.flac", streams: [], format: {})
      description = { "duration" => duration, "tags" => tags }.merge(format)
      probe = FakeFfprobe.new(streams:, format: description)

      Tags.new(ffprobe: probe).read(path)
    end
  end
end
