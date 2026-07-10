require "test_helper"
require "tmpdir"

module Video
  class ConversionTest < ActiveSupport::TestCase
    test "convierte un avi viejo en algo que el browser entiende" do
      converted = convert("viejo.avi")

      found = Probe.new.examine(converted)
      assert_equal "mp4", found.container
      assert_equal "h264", found.video.codec
    end

    test "un remux conserva el video sin recomprimirlo" do
      converted = convert("dos-pistas.mkv")

      assert_equal "h264", Probe.new.examine(converted).video.codec
    end

    test "elegir la segunda pista de audio entrega esa pista" do
      converted = convert("dos-pistas.mkv", audio: 1)

      # La pista 1 es FLAC, que el browser no entiende: sale recodificada a aac.
      assert_equal "aac", Probe.new.examine(converted).audios.sole.codec
    end

    test "entrega los bytes de a pedazos, sin juntar el archivo entero en memoria" do
      chunks = 0
      Conversion.new.stream(fixture("viejo.avi"), playback_for("viejo.avi")) { chunks += 1 }

      assert_operator chunks, :>, 0
    end

    # Arrancar en el segundo N sin leer los N segundos previos es lo que hace
    # posible el seek sobre un stream que no se puede pedir por rangos.
    test "puede arrancar en un punto del video" do
      arguments = Conversion.new.command(fixture("viejo.avi"), playback_for("viejo.avi"), from: 42)

      assert_includes arguments.each_cons(2).to_a, [ "-ss", "42" ]
      assert_operator arguments.index("-ss"), :<, arguments.index("-i"),
        "-ss va antes de -i, si no ffmpeg decodifica y descarta todo lo anterior"
    end

    test "un archivo que ffmpeg no puede leer levanta un error" do
      assert_raises(Conversion::Failed) do
        Conversion.new.stream(__FILE__, playback_for("viejo.avi")) { |chunk| chunk }
      end
    end

    private

    def fixture(name)
      Rails.root.join("test/fixtures/videos", name).to_s
    end

    def playback_for(name, audio: 0)
      Playback.for(Probe.new.examine(fixture(name)), audio:)
    end

    def convert(name, audio: 0)
      output = File.join(Dir.mktmpdir("conversion"), "salida.mp4")

      File.open(output, "wb") do |file|
        Conversion.new.stream(fixture(name), playback_for(name, audio:)) { |chunk| file.write(chunk) }
      end

      output
    end
  end
end
