require "test_helper"

module Video
  # Probe no corre procesos: interpreta lo que ffprobe dice. Estos tests le dan
  # salida real de ffprobe, grabada en test/fixtures/ffprobe, y no necesitan
  # tener ffmpeg instalado. Que ffprobe siga hablando así lo verifica
  # test/contracts/ffmpeg_contract_test.rb.
  class ProbeTest < ActiveSupport::TestCase
    include VideoBuilders

    test "lee el contenedor y la pista de video" do
      found = recorded_probe.examine("directo.mp4")

      assert_equal "mp4", found.container
      assert_equal "h264", found.video.codec
    end

    # El contenedor sale de la extensión, no de ffprobe: format_name dice
    # "matroska,webm" para los dos, y mkv no lo abre nadie mientras webm sí.
    test "el contenedor sale de la extensión" do
      assert_equal "avi", recorded_probe.examine("/donde/sea/viejo.avi").container
    end

    test "lee cada pista de audio con su idioma y su título" do
      found = recorded_probe.examine("dos-pistas.mkv")

      assert_equal %w[aac flac], found.audios.map(&:codec)
      assert_equal %w[spa eng], found.audios.map(&:language)
      assert_equal [ "Español", "English" ], found.audios.map(&:title)
    end

    # Los índices son los de ffmpeg dentro del grupo de audio (0:a:0, 0:a:1),
    # no los del archivo: es lo que -map necesita.
    test "las pistas de audio se numeran desde cero" do
      assert_equal [ 0, 1 ], recorded_probe.examine("dos-pistas.mkv").audios.map(&:index)
    end

    test "lee los canales de cada pista" do
      assert_equal [ 1, 1 ], recorded_probe.examine("dos-pistas.mkv").audios.map(&:channels)
    end

    test "un archivo sin audio no tiene pistas de audio" do
      assert_empty recorded_probe.examine("mudo.mkv").audios
    end

    test "reconoce un contenedor y un códec viejos" do
      found = recorded_probe.examine("viejo.avi")

      assert_equal "mpeg4", found.video.codec
      assert_equal "mp3", found.audios.sole.codec
    end

    # Una carátula embebida viaja como pista de video. Es una foto, no una
    # película, y tomarla por el video del archivo arruinaría la decisión.
    test "una carátula embebida no se confunde con el video" do
      probe = probe_reporting([
        { "codec_type" => "video", "codec_name" => "mjpeg", "disposition" => { "attached_pic" => 1 } },
        { "codec_type" => "video", "codec_name" => "h264", "disposition" => { "attached_pic" => 0 } }
      ])

      assert_equal "h264", probe.examine("pelicula.mkv").video.codec
    end

    test "un archivo sin pistas es ilegible" do
      assert_raises(Unreadable) { probe_reporting([]).examine("vacio.mkv") }
    end

    test "un archivo sin pistas de video se lee igual: puede ser solo audio" do
      probe = probe_reporting([ { "codec_type" => "audio", "codec_name" => "aac", "channels" => 2 } ])

      assert_nil probe.examine("solo-audio.mkv").video
    end

    # Lo que sale del probe es exactamente lo que Playback necesita leer.
    test "lo que sale del probe alimenta la decisión de reproducción" do
      assert Playback.for(recorded_probe.examine("directo.mp4")).direct?
      refute Playback.for(recorded_probe.examine("dos-pistas.mkv")).direct?
    end
  end
end
