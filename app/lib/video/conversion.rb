require "open3"

module Video
  # Runs ffmpeg and hands the bytes over as they come out, so the browser can
  # start watching while the rest of the file is still being converted.
  class Conversion
    Failed = Class.new(StandardError)

    CHUNK = 64.kilobytes

    def stream(path, playback, from: 0, &)
      Open3.popen3(*command(path, playback, from:)) do |input, output, errors, ffmpeg|
        input.close
        complaints = Thread.new { errors.read }

        begin
          pump(output, &)
        rescue StandardError
          # The viewer closed the tab. ffmpeg would happily keep converting a
          # two hour movie for nobody.
          terminate(ffmpeg)
          raise
        end

        verify(ffmpeg.value, complaints.value, path)
      end
    rescue Errno::ENOENT
      raise NotInstalled, "can't find #{ffmpeg.inspect}: install ffmpeg or point FFMPEG at the binary"
    end

    def command(path, playback, from: 0)
      [ ffmpeg, "-nostdin", "-loglevel", "error" ] +
        seek_arguments(from) +
        [ "-i", path.to_s ] +
        playback.arguments +
        [ "pipe:1" ]
    end

    private

    # -ss before -i seeks by jumping into the file. After -i, ffmpeg would
    # decode and discard everything before the mark — for the tenth minute of a
    # movie, nine minutes nobody will watch.
    def seek_arguments(from)
      from.to_i.positive? ? [ "-ss", from.to_i.to_s ] : []
    end

    def pump(output)
      while (chunk = output.read(CHUNK))
        yield chunk
      end
    end

    def terminate(ffmpeg)
      Process.kill("TERM", ffmpeg.pid) if ffmpeg.alive?
    rescue Errno::ESRCH
      # It exited on its own between the check and the signal.
    end

    def verify(status, complaints, path)
      return if status.success?

      raise Failed, "ffmpeg failed on #{path}: #{complaints.to_s.strip}"
    end

    def ffmpeg
      Rails.configuration.x.ffmpeg
    end
  end
end
