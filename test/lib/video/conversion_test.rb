require "test_helper"

module Video
  # Building the command is a decision; running it is an effect. These tests
  # look at the decision and don't need ffmpeg. Whether ffmpeg understands the
  # command is verified by test/contracts/ffmpeg_contract_test.rb.
  class ConversionTest < ActiveSupport::TestCase
    include VideoBuilders

    test "passes ffmpeg the file and the decision's arguments" do
      playback = Playback.for(media(container: "mkv"))
      arguments = Conversion.new.command("/movies/one.mkv", playback)

      assert_includes arguments.each_cons(2).to_a, [ "-i", "/movies/one.mkv" ]
      assert_equal "pipe:1", arguments.last
      assert playback.arguments.all? { |argument| arguments.include?(argument) }
    end

    test "without a starting point it doesn't ask ffmpeg to seek" do
      refute_includes Conversion.new.command("/one.mkv", Playback.for(media)), "-ss"
    end

    # Starting at second N without reading the previous N seconds is what
    # makes seek possible on a stream that can't be requested by range.
    test "can start at a point in the video" do
      arguments = Conversion.new.command("/one.mkv", Playback.for(media), from: 42)

      assert_includes arguments.each_cons(2).to_a, [ "-ss", "42" ]
    end

    # After -i, ffmpeg would decode and discard everything before the seek
    # point: for minute ten of a movie, nine minutes nobody watches.
    test "the seek comes before the file, not after" do
      arguments = Conversion.new.command("/one.mkv", Playback.for(media), from: 42)

      assert_operator arguments.index("-ss"), :<, arguments.index("-i")
    end

    test "doesn't ask ffmpeg to read from standard input, which nobody will write to" do
      assert_includes Conversion.new.command("/one.mkv", Playback.for(media)), "-nostdin"
    end
  end
end
