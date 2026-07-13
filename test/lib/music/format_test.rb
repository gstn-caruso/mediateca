require "test_helper"

module Music
  class FormatTest < ActiveSupport::TestCase
    test "the formats the library holds are audio" do
      assert Format.audio?("A/1995 - B/01 - Mundo guanaco.flac")
      assert Format.audio?("A/2026 - B/01 - Yo soy.opus")
      assert Format.audio?("A/2026 - B/01 - Yo soy.mp3")
    end

    test "whatever else sits in an album folder is not" do
      assert_not Format.audio?("A/1995 - B/cover.jpg")
      assert_not Format.audio?("A/1995 - B/notas.txt")
      assert_not Format.audio?("A/1995 - B/01 - Mundo guanaco.lrc")
      assert_not Format.audio?("A/1995 - B")
    end

    # ".FLAC" came off a Windows ripper, and it is the same file as ".flac".
    test "the extension is read regardless of case" do
      assert Format.audio?("A/1995 - B/01.FLAC")
      assert_equal "audio/flac", Format.content_type("A/1995 - B/01.FLAC")
    end

    test "each format is served under the type its container is named by" do
      assert_equal "audio/flac", Format.content_type("01.flac")
      assert_equal "audio/ogg", Format.content_type("01.opus")
      assert_equal "audio/mpeg", Format.content_type("01.mp3")
    end

    # A file we cannot name a type for is a file we never counted as a track,
    # so nothing should ever ask — and if something does, it gets no answer
    # rather than a wrong one.
    test "a format the library does not hold has no type" do
      assert_nil Format.content_type("cover.jpg")
    end
  end
end
