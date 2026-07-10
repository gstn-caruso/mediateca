require "test_helper"
require "open3"
require "tmpdir"

# Los únicos tests que corren ffmpeg de verdad.
#
# El resto de la suite trabaja contra salida de ffprobe grabada y contra
# comandos que nadie ejecuta, así que no necesita tenerlo instalado. Lo que
# nadie más puede verificar es lo que estos tests verifican: que ffprobe siga
# describiendo los archivos como los grabamos, y que ffmpeg entienda los
# argumentos que armamos.
#
# Se saltean si ffmpeg no está. En CI está, así que no se saltean nunca.
class FfmpegContractTest < ActiveSupport::TestCase
  include VideoBuilders

  RECORDED = %w[directo.mp4 dos-pistas.mkv mudo.mkv viejo.avi].freeze

  setup do
    next if ffmpeg_installed?

    # Saltearse en silencio donde se supone que tienen que correr sería peor que
    # no tenerlos: la suite quedaría verde sin haber verificado nada.
    flunk "ffmpeg no está instalado y REQUIRE_FFMPEG lo exige" if ENV["REQUIRE_FFMPEG"].present?

    skip "ffmpeg no está instalado"
  end

  test "la salida grabada de ffprobe sigue coincidiendo con la real" do
    RECORDED.each do |name|
      real = Video::Probe.new.examine(fixture(name))
      recorded = recorded_probe.examine(name)

      assert_equal recorded, real,
        "la grabación en test/fixtures/ffprobe/#{name.sub(/\.\w+$/, '.json')} quedó vieja"
    end
  end

  test "ffprobe rechaza lo que no es un video" do
    assert_raises(Video::Unreadable) { Ffprobe.new.describe(__FILE__) }
  end

  test "ffmpeg convierte un avi viejo en algo que el browser entiende" do
    found = Video::Probe.new.examine(convert("viejo.avi"))

    assert_equal "mp4", found.container
    assert_equal "h264", found.video.codec
  end

  test "ffmpeg remuxea sin recomprimir el video" do
    assert_equal "h264", Video::Probe.new.examine(convert("dos-pistas.mkv")).video.codec
  end

  test "ffmpeg entrega la pista de audio que se le pide" do
    # La pista 1 es FLAC, que el browser no entiende: sale recodificada a aac.
    assert_equal "aac", Video::Probe.new.examine(convert("dos-pistas.mkv", audio: 1)).audios.sole.codec
  end

  test "ni los capítulos ni las pistas de datos llegan a la salida" do
    streams = Ffprobe.new.describe(convert("dos-pistas.mkv")).fetch("streams")

    assert_empty streams.select { |stream| stream["codec_type"] == "data" }
  end

  test "entrega los bytes de a pedazos, sin juntar el archivo entero en memoria" do
    chunks = 0
    Video::Conversion.new.stream(fixture("viejo.avi"), playback_for("viejo.avi")) { chunks += 1 }

    assert_operator chunks, :>, 0
  end

  test "un archivo que ffmpeg no puede leer levanta un error" do
    assert_raises(Video::Conversion::Failed) do
      Video::Conversion.new.stream(__FILE__, playback_for("viejo.avi")) { |chunk| chunk }
    end
  end

  private

  def ffmpeg_installed?
    [ Rails.configuration.x.ffmpeg, Rails.configuration.x.ffprobe ].all? do |binary|
      Open3.capture3(binary, "-version")
      true
    rescue Errno::ENOENT
      false
    end
  end

  def fixture(name)
    Rails.root.join("test/fixtures/videos", name).to_s
  end

  def playback_for(name, audio: 0)
    Video::Playback.for(Video::Probe.new.examine(fixture(name)), audio:)
  end

  def convert(name, audio: 0)
    output = File.join(Dir.mktmpdir("conversion"), "salida.mp4")

    File.open(output, "wb") do |file|
      Video::Conversion.new.stream(fixture(name), playback_for(name, audio:)) { |chunk| file.write(chunk) }
    end

    output
  end
end
