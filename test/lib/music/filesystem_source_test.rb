require "test_helper"
require "tmpdir"
require "fileutils"

module Music
  class FilesystemSourceTest < ActiveSupport::TestCase
    test "una raíz vacía no reporta álbumes" do
      within_root { |root| assert_empty source(root).albums }
    end

    test "un directorio de álbum con sus flac es un álbum" do
      within_root do |root|
        create(root, "Indio Solari/2010 - El perfume de la tempestad/05 - Satelital.flac",
          album: "El perfume de la tempestad", album_artist: "Indio Solari", year: 2010,
          genre: "Rock nacional", title: "Satelital", track_no: 5, duration: 266.4)

        album = source(root).albums.sole

        assert_equal "#{root}/Indio Solari/2010 - El perfume de la tempestad", album.directory
        assert_equal "El perfume de la tempestad", album.title
        assert_equal "Indio Solari", album.artist
        assert_equal 2010, album.year
        assert_equal "Rock nacional", album.genre
        assert_equal 1, album.disc_total

        track = album.tracks.sole
        assert_equal "Satelital", track.title
        assert_equal 5, track.track_no
        assert_in_delta 266.4, track.duration
      end
    end

    # 1074 de los 1171 flac del NAS viven a profundidad 2. Los otros 97 cuelgan
    # de un CDn dentro del álbum, y siguen siendo del mismo álbum.
    test "los tracks en subcarpetas por disco pertenecen al álbum, no a la subcarpeta" do
      within_root do |root|
        create(root, "Green Day/2025 - Warning/CD01/01 - Uno.flac", disc_no: 1, track_no: 1)
        create(root, "Green Day/2025 - Warning/CD02/01 - Dos.flac", disc_no: 2, track_no: 1)

        album = source(root).albums.sole

        assert_equal "#{root}/Green Day/2025 - Warning", album.directory
        assert_equal 2, album.tracks.size
        assert_equal 2, album.disc_total
      end
    end

    test "los tracks salen ordenados por disco y número" do
      within_root do |root|
        create(root, "A/1990 - B/z.flac", disc_no: 2, track_no: 1, title: "d2t1")
        create(root, "A/1990 - B/a.flac", disc_no: 1, track_no: 2, title: "d1t2")
        create(root, "A/1990 - B/m.flac", disc_no: 1, track_no: 1, title: "d1t1")

        assert_equal %w[d1t1 d1t2 d2t1], source(root).albums.sole.tracks.map(&:title)
      end
    end

    test "dos álbumes del mismo artista son dos álbumes" do
      within_root do |root|
        create(root, "Hermética/1989 - Hermética/01.flac", album: "Hermética")
        create(root, "Hermética/1991 - Ácido Argentino/01.flac", album: "Ácido Argentino")

        assert_equal 2, source(root).albums.size
      end
    end

    # Beets eligió cover.1.jpg para los 6 álbumes de Almafuerte, y pesa
    # exactamente lo mismo que "Cover back.jpg": es la contratapa.
    test "la carátula es la tapa, nunca la contratapa" do
      within_root do |root|
        create(root, "Almafuerte/1995 - Mundo guanaco/01.flac")
        directory = "#{root}/Almafuerte/1995 - Mundo guanaco"
        %w[cover.1.jpg Cover\ back.jpg Cover\ front.jpg cover.jpg].each { |name| touch("#{directory}/#{name}") }

        assert_equal "#{directory}/cover.jpg", source(root).albums.sole.cover_path
      end
    end

    test "sin cover.jpg vale front.jpg" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")
        touch("#{root}/A/1990 - B/back.jpg")
        touch("#{root}/A/1990 - B/front.jpg")

        assert_equal "#{root}/A/1990 - B/front.jpg", source(root).albums.sole.cover_path
      end
    end

    test "un álbum sin ninguna imagen no tiene carátula" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")

        assert_nil source(root).albums.sole.cover_path
      end
    end

    # Sin tags, el nombre de las carpetas es lo único que queda.
    test "sin tags, el álbum y el artista salen de los nombres de carpeta" do
      within_root do |root|
        create(root, "Indio Solari/2010 - El perfume de la tempestad/01.flac", album: nil, album_artist: nil, year: nil)

        album = source(root).albums.sole

        assert_equal "El perfume de la tempestad", album.title
        assert_equal "Indio Solari", album.artist
        assert_equal 2010, album.year
      end
    end

    test "lo que no es un flac se ignora" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")
        touch("#{root}/A/1990 - B/notas.txt")
        touch("#{root}/A/1990 - B/01.mp3")

        assert_equal 1, source(root).albums.sole.tracks.size
      end
    end

    private

    # Un lector de tags de mentira: los tags salen de lo que declaró el test, no
    # de leer el archivo. Así el scanner se prueba sin ffmpeg y sin FLACs reales.
    class DeclaredTags
      def initialize = @by_path = {}

      def declare(path, **tags) = @by_path[path] = tags

      def read(path)
        tags = @by_path.fetch(path, {})

        Music::FileTags.new(
          title: tags.fetch(:title, File.basename(path, ".*")),
          artist: tags[:artist],
          album_artist: tags[:album_artist],
          album: tags[:album],
          year: tags[:year],
          genre: tags[:genre],
          track_no: tags.fetch(:track_no, 1),
          disc_no: tags.fetch(:disc_no, 1),
          duration: tags.fetch(:duration, 1.0)
        )
      end
    end

    def within_root
      Dir.mktmpdir("music-root") { |root| yield File.realpath(root) }
    end

    def source(root)
      FilesystemSource.new(root:, tags: @tags || DeclaredTags.new)
    end

    def create(root, relative, **tags)
      @tags ||= DeclaredTags.new
      path = File.join(root, relative)
      touch(path)
      @tags.declare(path, **tags)
      path
    end

    def touch(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "")
    end

    def teardown
      @tags = nil
    end
  end
end
