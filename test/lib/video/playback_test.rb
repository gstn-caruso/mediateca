require "test_helper"

module Video
  # The rules come from surveying the NAS's 605 videos with ffprobe, not from
  # guessing: h264 441, hevc 93, mpeg4 60, av1 5, vp9 3, msmpeg4v3 3;
  # aac 640, mp3 53, flac 46, ac3 39, eac3 12, opus 3, dts 1.
  class PlaybackTest < ActiveSupport::TestCase
    include VideoBuilders

    # --- Direct play: the client understands the file as-is -----------

    test "an mp4 of h264 and aac is served as-is" do
      playback = Playback.for(media(container: "mp4", video: "h264", audios: [ "aac" ]))

      assert playback.direct?
      assert_equal "video/mp4", playback.content_type
    end

    test "a webm of vp9 and opus is served as-is" do
      assert Playback.for(media(container: "webm", video: "vp9", audios: [ "opus" ])).direct?
    end

    test "an mp4 of hevc is served as-is" do
      assert Playback.for(media(container: "mp4", video: "hevc", audios: [ "aac" ])).direct?
    end

    # --- Remux: the codecs work, the container doesn't -------------------------

    # No Safari opens an MKV, and Chrome only sometimes does. But changing the
    # container doesn't touch the video bits: it's copying, not recompressing.
    test "an mkv of h264 and aac is remuxed without recompressing anything" do
      playback = Playback.for(media(container: "mkv", video: "h264", audios: [ "aac" ]))

      refute playback.direct?
      assert_equal "video/mp4", playback.content_type
      assert_includes_pair playback.arguments, "-c:v", "copy"
      assert_includes_pair playback.arguments, "-c:a", "copy"
    end

    test "the remux comes out as fragmented mp4, which can start playing without the whole file" do
      arguments = Playback.for(media(container: "mkv")).arguments

      assert_includes_pair arguments, "-f", "mp4"
      assert_includes_pair arguments, "-movflags", "frag_keyframe+empty_moov+default_base_moof"
    end

    # --- The audio isn't understood: only the audio gets recompressed ---------------

    test "an mkv of hevc with flac audio copies the video and recompresses the audio" do
      arguments = Playback.for(media(container: "mkv", video: "hevc", audios: [ "flac" ])).arguments

      assert_includes_pair arguments, "-c:v", "copy"
      assert_includes_pair arguments, "-c:a", "aac"
    end

    test "a 5.1 ac3 is downmixed to stereo, which is what the browser can play" do
      arguments = Playback.for(media(container: "mkv", audios: [ "ac3" ], channels: 6)).arguments

      assert_includes_pair arguments, "-c:a", "aac"
      assert_includes_pair arguments, "-ac", "2"
    end

    test "audio that's already understood isn't touched even if it's 5.1" do
      arguments = Playback.for(media(container: "mkv", audios: [ "aac" ], channels: 6)).arguments

      assert_includes_pair arguments, "-c:a", "copy"
      refute_includes arguments, "-ac"
    end

    # --- The video isn't understood: only then does it get transcoded ---------------

    test "an avi of mpeg4 does get transcoded: no browser opens it" do
      arguments = Playback.for(media(container: "avi", video: "mpeg4", audios: [ "mp3" ])).arguments

      assert_includes_pair arguments, "-c:v", "libx264"
      assert_includes_pair arguments, "-c:a", "copy"
    end

    test "an msmpeg4v3 also gets transcoded" do
      arguments = Playback.for(media(container: "avi", video: "msmpeg4v3", audios: [ "mp3" ])).arguments

      assert_includes_pair arguments, "-c:v", "libx264"
    end

    # --- Audio track selection ----------------------------------------

    # 125 of the 605 files have 2 or 3 audio tracks. A <video> serving the raw
    # file delivers the first one and doesn't allow switching it; picking
    # another one requires a remux even if the codecs would otherwise be fine.
    test "requesting an audio track other than the first forces a remux" do
      playback = Playback.for(media(container: "mp4", video: "h264", audios: [ "aac", "aac" ]), audio: 1)

      refute playback.direct?
      assert_includes_pair playback.arguments, "-map", "0:a:1"
    end

    test "the first track is requested by default" do
      assert_includes_pair Playback.for(media(container: "mkv")).arguments, "-map", "0:a:0"
    end

    test "the video always comes from the first video track" do
      assert_includes_pair Playback.for(media(container: "mkv")).arguments, "-map", "0:v:0"
    end

    # --- Edge cases -------------------------------------------------------------

    test "embedded subtitles don't get mixed into the stream" do
      assert_includes Playback.for(media(container: "mkv")).arguments, "-sn"
    end

    # An MKV with chapters muxes them as a text track in the mp4, which
    # ffprobe reports as `bin_data`. Nobody asked for it and nothing reads it.
    test "neither chapters nor data tracks make it into the stream" do
      arguments = Playback.for(media(container: "mkv")).arguments

      assert_includes arguments, "-dn"
      assert_includes_pair arguments, "-map_chapters", "-1"
    end

    test "a file with no audio is still served" do
      playback = Playback.for(media(container: "mkv", audios: []))

      refute playback.direct?
      refute_includes playback.arguments, "-c:a"
    end

    test "requesting an audio track that doesn't exist falls back to the first one" do
      assert_includes_pair Playback.for(media(container: "mkv", audios: [ "aac" ]), audio: 7).arguments, "-map", "0:a:0"
    end

    private

    # -map appears more than once (video and audio), so looking for the
    # flag's first position isn't enough: we need to check whether the pair exists anywhere.
    def assert_includes_pair(arguments, flag, value)
      assert_includes arguments.each_cons(2).to_a, [ flag, value ],
        "expected #{flag} #{value} in #{arguments.inspect}"
    end
  end
end
