require "test_helper"

module Video
  class FfprobeTest < ActiveSupport::TestCase
    # Sin ffprobe, Open3 tira Errno::ENOENT y el mensaje no dice qué instalar.
    # Este test no necesita ffmpeg: necesita justamente su ausencia.
    test "si ffprobe no está instalado, el error lo dice" do
      original = Rails.configuration.x.ffprobe
      Rails.configuration.x.ffprobe = "ffprobe-que-no-existe"

      error = assert_raises(NotInstalled) { Ffprobe.new.streams("cualquier.mkv") }
      assert_match(/ffprobe-que-no-existe/, error.message)
      assert_match(/instalá ffmpeg/, error.message)
    ensure
      Rails.configuration.x.ffprobe = original
    end
  end
end
