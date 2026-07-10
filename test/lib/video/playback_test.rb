require "test_helper"

module Video
  # Las reglas salen de censar los 605 videos del NAS con ffprobe, no de
  # suponer: h264 441, hevc 93, mpeg4 60, av1 5, vp9 3, msmpeg4v3 3;
  # aac 640, mp3 53, flac 46, ac3 39, eac3 12, opus 3, dts 1.
  class PlaybackTest < ActiveSupport::TestCase
    include VideoBuilders

    # --- Direct play: el cliente entiende el archivo tal cual está -----------

    test "un mp4 de h264 y aac se sirve tal cual" do
      playback = Playback.for(media(container: "mp4", video: "h264", audios: [ "aac" ]))

      assert playback.direct?
      assert_equal "video/mp4", playback.content_type
    end

    test "un webm de vp9 y opus se sirve tal cual" do
      assert Playback.for(media(container: "webm", video: "vp9", audios: [ "opus" ])).direct?
    end

    test "un mp4 de hevc se sirve tal cual" do
      assert Playback.for(media(container: "mp4", video: "hevc", audios: [ "aac" ])).direct?
    end

    # --- Remux: los códecs sirven, el contenedor no -------------------------

    # Ningún Safari abre un MKV, y Chrome solo a veces. Pero cambiar el
    # contenedor no toca los bits del video: es copiar, no recomprimir.
    test "un mkv de h264 y aac se remuxea sin recomprimir nada" do
      playback = Playback.for(media(container: "mkv", video: "h264", audios: [ "aac" ]))

      refute playback.direct?
      assert_equal "video/mp4", playback.content_type
      assert_includes_pair playback.arguments, "-c:v", "copy"
      assert_includes_pair playback.arguments, "-c:a", "copy"
    end

    test "el remux sale como mp4 fragmentado, que se puede empezar a mirar sin el archivo entero" do
      arguments = Playback.for(media(container: "mkv")).arguments

      assert_includes_pair arguments, "-f", "mp4"
      assert_includes_pair arguments, "-movflags", "frag_keyframe+empty_moov+default_base_moof"
    end

    # --- El audio no se entiende: se recomprime solo el audio ---------------

    test "un mkv de hevc con audio flac copia el video y recomprime el audio" do
      arguments = Playback.for(media(container: "mkv", video: "hevc", audios: [ "flac" ])).arguments

      assert_includes_pair arguments, "-c:v", "copy"
      assert_includes_pair arguments, "-c:a", "aac"
    end

    test "un ac3 de 5.1 se baja a estéreo, que es lo que el browser puede sonar" do
      arguments = Playback.for(media(container: "mkv", audios: [ "ac3" ], channels: 6)).arguments

      assert_includes_pair arguments, "-c:a", "aac"
      assert_includes_pair arguments, "-ac", "2"
    end

    test "un audio que ya se entiende no se toca aunque sea 5.1" do
      arguments = Playback.for(media(container: "mkv", audios: [ "aac" ], channels: 6)).arguments

      assert_includes_pair arguments, "-c:a", "copy"
      refute_includes arguments, "-ac"
    end

    # --- El video no se entiende: recién ahí se transcodifica ---------------

    test "un avi de mpeg4 sí se transcodifica: ningún browser lo abre" do
      arguments = Playback.for(media(container: "avi", video: "mpeg4", audios: [ "mp3" ])).arguments

      assert_includes_pair arguments, "-c:v", "libx264"
      assert_includes_pair arguments, "-c:a", "copy"
    end

    test "un msmpeg4v3 también se transcodifica" do
      arguments = Playback.for(media(container: "avi", video: "msmpeg4v3", audios: [ "mp3" ])).arguments

      assert_includes_pair arguments, "-c:v", "libx264"
    end

    # --- Selección de pista de audio ----------------------------------------

    # 125 de los 605 archivos tienen 2 o 3 pistas de audio. Un <video> sirviendo
    # el archivo crudo entrega la primera y no deja cambiarla; para elegir otra
    # hay que remuxear aunque los códecs alcancen.
    test "pedir una pista de audio que no es la primera obliga a remuxear" do
      playback = Playback.for(media(container: "mp4", video: "h264", audios: [ "aac", "aac" ]), audio: 1)

      refute playback.direct?
      assert_includes_pair playback.arguments, "-map", "0:a:1"
    end

    test "la primera pista se pide por defecto" do
      assert_includes_pair Playback.for(media(container: "mkv")).arguments, "-map", "0:a:0"
    end

    test "el video siempre sale de la primera pista de video" do
      assert_includes_pair Playback.for(media(container: "mkv")).arguments, "-map", "0:v:0"
    end

    # --- Bordes -------------------------------------------------------------

    test "los subtítulos embebidos no se meten en el stream" do
      assert_includes Playback.for(media(container: "mkv")).arguments, "-sn"
    end

    # Un MKV con capítulos los muxea como un track de texto en el mp4, que
    # ffprobe reporta como `bin_data`. Nadie lo pidió y nada lo lee.
    test "ni los capítulos ni las pistas de datos entran en el stream" do
      arguments = Playback.for(media(container: "mkv")).arguments

      assert_includes arguments, "-dn"
      assert_includes_pair arguments, "-map_chapters", "-1"
    end

    test "un archivo sin audio se sirve igual" do
      playback = Playback.for(media(container: "mkv", audios: []))

      refute playback.direct?
      refute_includes playback.arguments, "-c:a"
    end

    test "pedir una pista de audio que no existe cae en la primera" do
      assert_includes_pair Playback.for(media(container: "mkv", audios: [ "aac" ]), audio: 7).arguments, "-map", "0:a:0"
    end

    private

    # -map aparece más de una vez (video y audio), así que buscar la primera
    # posición del flag no alcanza: hay que ver si el par existe en algún lado.
    def assert_includes_pair(arguments, flag, value)
      assert_includes arguments.each_cons(2).to_a, [ flag, value ],
        "esperaba #{flag} #{value} en #{arguments.inspect}"
    end
  end
end
