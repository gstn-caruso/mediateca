module Video
  # Decides how a media file reaches the browser: untouched, repackaged, or
  # re-encoded — in that order of preference, because each step costs more.
  #
  # The three sets below were measured with ffprobe over the 605 videos on the
  # NAS, not guessed. Anything outside them is what ffmpeg is for.
  class Playback
    # A container the browser will open. MKV is absent on purpose: Safari never
    # opens one and Chrome only sometimes, however good the codecs inside are.
    PLAYABLE_CONTAINERS = %w[mp4 m4v mov webm].freeze

    # Video the browser can decode, so its bits can be copied across containers
    # instead of re-encoded.
    PLAYABLE_VIDEO = %w[h264 hevc av1 vp9].freeze

    # Audio the browser can decode. Absent, and costly: flac, ac3, eac3, dts.
    PLAYABLE_AUDIO = %w[aac mp3 opus].freeze

    # Browsers play stereo. A 5.1 track that has to be re-encoded anyway may as
    # well be folded down on the way.
    STEREO = "2".freeze

    def self.for(media, audio: 0)
      new(media, audio)
    end

    def initialize(media, audio)
      @media = media
      @audio = media.audios.any? && media.audios[audio] ? audio : 0
    end

    # Nothing to do: hand the file over and let the browser seek through it.
    def direct?
      playable_container? && playable_video? && playable_audio? && default_audio?
    end

    def content_type
      direct? && media.container == "webm" ? "video/webm" : "video/mp4"
    end

    def arguments
      selected_streams + video_arguments + audio_arguments + output_arguments
    end

    private

    attr_reader :media, :audio

    def selected_streams
      streams = [ "-map", "0:v:0" ]
      streams += [ "-map", "0:a:#{audio}" ] if audible?
      streams
    end

    def video_arguments
      return [ "-c:v", "copy" ] if playable_video?

      [ "-c:v", "libx264", "-preset", "veryfast", "-crf", "21" ]
    end

    def audio_arguments
      return [] unless audible?
      return [ "-c:a", "copy" ] if playable_audio?

      [ "-c:a", "aac" ] + (surround? ? [ "-ac", STEREO ] : [])
    end

    # Fragmented MP4: the browser can start watching before ffmpeg has finished,
    # which is the whole point of streaming rather than converting.
    #
    # Subtitles, data and chapters are dropped. An MKV's chapters otherwise
    # arrive as a text track that no browser reads and ffprobe calls `bin_data`.
    def output_arguments
      [ "-sn", "-dn", "-map_chapters", "-1",
        "-f", "mp4", "-movflags", "frag_keyframe+empty_moov+default_base_moof" ]
    end

    def audible?
      media.audios.any?
    end

    def selected_audio
      media.audios[audio]
    end

    def surround?
      selected_audio.channels.to_i > 2
    end

    def playable_container?
      PLAYABLE_CONTAINERS.include?(media.container)
    end

    def playable_video?
      media.video && PLAYABLE_VIDEO.include?(media.video.codec)
    end

    def playable_audio?
      !audible? || PLAYABLE_AUDIO.include?(selected_audio.codec)
    end

    # A plain <video> hands over the file's first audio track and offers no way
    # to switch, so wanting any other track is reason enough to repackage.
    def default_audio?
      audio.zero?
    end
  end
end
