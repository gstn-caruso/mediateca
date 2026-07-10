require "test_helper"

module Video
  class ProbeTest < ActiveSupport::TestCase
    test "lee el contenedor y la pista de video" do
      found = Probe.new.examine(fixture("directo.mp4"))

      assert_equal "mp4", found.container
      assert_equal "h264", found.video.codec
    end

    test "lee cada pista de audio con su idioma y su título" do
      found = Probe.new.examine(fixture("dos-pistas.mkv"))

      assert_equal %w[aac flac], found.audios.map(&:codec)
      assert_equal %w[spa eng], found.audios.map(&:language)
      assert_equal [ "Español", "English" ], found.audios.map(&:title)
    end

    # Los índices son los de ffmpeg dentro del grupo de audio (0:a:0, 0:a:1),
    # no los del archivo: es lo que -map necesita.
    test "las pistas de audio se numeran desde cero" do
      found = Probe.new.examine(fixture("dos-pistas.mkv"))

      assert_equal [ 0, 1 ], found.audios.map(&:index)
    end

    test "lee los canales de cada pista" do
      found = Probe.new.examine(fixture("dos-pistas.mkv"))

      assert_equal [ 1, 1 ], found.audios.map(&:channels)
    end

    test "un archivo sin audio no tiene pistas de audio" do
      assert_empty Probe.new.examine(fixture("mudo.mkv")).audios
    end

    test "reconoce un contenedor y un códec viejos" do
      found = Probe.new.examine(fixture("viejo.avi"))

      assert_equal "avi", found.container
      assert_equal "mpeg4", found.video.codec
      assert_equal "mp3", found.audios.sole.codec
    end

    test "un archivo que no es video levanta un error claro" do
      assert_raises(Probe::Unreadable) { Probe.new.examine(__FILE__) }
    end

    # Lo que devuelve el probe es exactamente lo que Playback necesita leer.
    test "lo que sale del probe alimenta la decisión de reproducción" do
      assert Playback.for(Probe.new.examine(fixture("directo.mp4"))).direct?
      refute Playback.for(Probe.new.examine(fixture("dos-pistas.mkv"))).direct?
    end

    private

    def fixture(name)
      Rails.root.join("test/fixtures/videos", name).to_s
    end
  end
end
