require "test_helper"

module Video
  # Armar el comando es una decisión; correrlo es un efecto. Estos tests miran
  # la decisión y no necesitan ffmpeg. Que ffmpeg entienda el comando lo
  # verifica test/contracts/ffmpeg_contract_test.rb.
  class ConversionTest < ActiveSupport::TestCase
    include VideoBuilders

    test "le pasa a ffmpeg el archivo y los argumentos de la decisión" do
      playback = Playback.for(media(container: "mkv"))
      arguments = Conversion.new.command("/peliculas/una.mkv", playback)

      assert_includes arguments.each_cons(2).to_a, [ "-i", "/peliculas/una.mkv" ]
      assert_equal "pipe:1", arguments.last
      assert playback.arguments.all? { |argument| arguments.include?(argument) }
    end

    test "sin punto de arranque no le pide a ffmpeg que salte" do
      refute_includes Conversion.new.command("/una.mkv", Playback.for(media)), "-ss"
    end

    # Arrancar en el segundo N sin leer los N segundos previos es lo que hace
    # posible el seek sobre un stream que no se puede pedir por rangos.
    test "puede arrancar en un punto del video" do
      arguments = Conversion.new.command("/una.mkv", Playback.for(media), from: 42)

      assert_includes arguments.each_cons(2).to_a, [ "-ss", "42" ]
    end

    # Después de -i, ffmpeg decodificaría y descartaría todo lo anterior al
    # salto: para el minuto diez de una película, nueve minutos que nadie mira.
    test "el salto va antes del archivo, no después" do
      arguments = Conversion.new.command("/una.mkv", Playback.for(media), from: 42)

      assert_operator arguments.index("-ss"), :<, arguments.index("-i")
    end

    test "no le pide a ffmpeg leer de la entrada estándar, que nadie va a escribir" do
      assert_includes Conversion.new.command("/una.mkv", Playback.for(media)), "-nostdin"
    end
  end
end
