require "test_helper"

module Music
  # Los casos salen de los tags reales del NAS, leídos con ffprobe.
  class TagsTest < ActiveSupport::TestCase
    test "lee lo que el archivo dice de sí mismo" do
      tags = read({
        "ALBUM" => "El perfume de la tempestad",
        "ARTIST" => "Indio Solari",
        "DATE" => "2010",
        "GENRE" => "Rock nacional",
        "TITLE" => "Una rata muerta entre los Geranios",
        "album_artist" => "Indio Solari",
        "track" => "12"
      }, duration: "266.400000")

      assert_equal "Una rata muerta entre los Geranios", tags.title
      assert_equal "Indio Solari", tags.artist
      assert_equal "Indio Solari", tags.album_artist
      assert_equal "El perfume de la tempestad", tags.album
      assert_equal 2010, tags.year
      assert_equal "Rock nacional", tags.genre
      assert_equal 12, tags.track_no
      assert_equal 1, tags.disc_no
      assert_in_delta 266.4, tags.duration
    end

    # ffprobe devuelve las claves como las escribió quien tagueó: ALBUM,
    # album_artist, Track... Todas quieren decir lo mismo.
    test "las claves se leen sin importar cómo estén escritas" do
      assert_equal "Hypnotize", read({ "album" => "Hypnotize" }).album
      assert_equal "Hypnotize", read({ "ALBUM" => "Hypnotize" }).album
      assert_equal "Hypnotize", read({ "Album" => "Hypnotize" }).album
    end

    # DATE viene a veces como '2010' y a veces como '2005-11-22'.
    test "el año se extrae de una fecha completa" do
      assert_equal 2005, read({ "DATE" => "2005-11-22" }).year
      assert_equal 2010, read({ "DATE" => "2010" }).year
      assert_nil read({}).year
    end

    test "el número de track puede venir como 3/12" do
      assert_equal 3, read({ "track" => "3/12" }).track_no
      assert_equal 3, read({ "tracknumber" => "3" }).track_no
      assert_nil read({}).track_no
    end

    test "sin número de disco, el disco es el uno" do
      assert_equal 1, read({}).disc_no
      assert_equal 2, read({ "disc" => "2/3" }).disc_no
      assert_equal 2, read({ "discnumber" => "2" }).disc_no
    end

    # Un archivo sin ALBUMARTIST pero con ARTIST: el artista del álbum es ese.
    test "sin artista de álbum, vale el del track" do
      assert_equal "Hermética", read({ "ARTIST" => "Hermética" }).album_artist
    end

    test "sin título, vale el nombre del archivo" do
      tags = read({}, path: "/m/Indio Solari/2010 - X/05 - Satelital.flac")

      assert_equal "05 - Satelital", tags.title
    end

    test "un tag vacío es como no tenerlo" do
      assert_nil read({ "GENRE" => "", "ALBUM" => "  " }).genre
      assert_nil read({ "GENRE" => "", "ALBUM" => "  " }).album
    end

    private

    def read(tags, duration: "1.0", path: "/m/Artista/1995 - Album/01 - Tema.flac")
      probe = VideoBuilders::FakeFfprobe.new(format: { "duration" => duration, "tags" => tags })

      Tags.new(ffprobe: probe).read(path)
    end
  end
end
