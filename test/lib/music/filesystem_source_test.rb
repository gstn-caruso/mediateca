require "test_helper"
require "tmpdir"
require "fileutils"

module Music
  class FilesystemSourceTest < ActiveSupport::TestCase
    test "an empty root reports no albums" do
      within_root { |root| assert_empty source(root).albums }
    end

    test "an album directory with its flacs is an album" do
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

    # 1074 of the NAS's 1171 flacs live at depth 2. The other 97 hang off a
    # CDn inside the album, and still belong to the same album.
    test "tracks in subfolders by disc belong to the album, not the subfolder" do
      within_root do |root|
        create(root, "Green Day/2025 - Warning/CD01/01 - Uno.flac", disc_no: 1, track_no: 1)
        create(root, "Green Day/2025 - Warning/CD02/01 - Dos.flac", disc_no: 2, track_no: 1)

        album = source(root).albums.sole

        assert_equal "#{root}/Green Day/2025 - Warning", album.directory
        assert_equal 2, album.tracks.size
        assert_equal 2, album.disc_total
      end
    end

    test "tracks come out ordered by disc and number" do
      within_root do |root|
        create(root, "A/1990 - B/z.flac", disc_no: 2, track_no: 1, title: "d2t1")
        create(root, "A/1990 - B/a.flac", disc_no: 1, track_no: 2, title: "d1t2")
        create(root, "A/1990 - B/m.flac", disc_no: 1, track_no: 1, title: "d1t1")

        assert_equal %w[d1t1 d1t2 d2t1], source(root).albums.sole.tracks.map(&:title)
      end
    end

    test "two albums by the same artist are two albums" do
      within_root do |root|
        create(root, "Hermética/1989 - Hermética/01.flac", album: "Hermética")
        create(root, "Hermética/1991 - Ácido Argentino/01.flac", album: "Ácido Argentino")

        assert_equal 2, source(root).albums.size
      end
    end

    # Beets picked cover.1.jpg for Almafuerte's 6 albums, and it weighs
    # exactly the same as "Cover back.jpg": it's the back cover.
    test "the cover is the front, never the back" do
      within_root do |root|
        create(root, "Almafuerte/1995 - Mundo guanaco/01.flac")
        directory = "#{root}/Almafuerte/1995 - Mundo guanaco"
        %w[cover.1.jpg Cover\ back.jpg Cover\ front.jpg cover.jpg].each { |name| touch("#{directory}/#{name}") }

        assert_equal "#{directory}/cover.jpg", source(root).albums.sole.cover_path
      end
    end

    test "without cover.jpg, front.jpg works" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")
        touch("#{root}/A/1990 - B/back.jpg")
        touch("#{root}/A/1990 - B/front.jpg")

        assert_equal "#{root}/A/1990 - B/front.jpg", source(root).albums.sole.cover_path
      end
    end

    test "an album with no image at all has no cover" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")

        assert_nil source(root).albums.sole.cover_path
      end
    end

    # Without tags, the folder names are all that's left.
    test "without tags, album and artist come from the folder names" do
      within_root do |root|
        create(root, "Indio Solari/2010 - El perfume de la tempestad/01.flac", album: nil, album_artist: nil, year: nil)

        album = source(root).albums.sole

        assert_equal "El perfume de la tempestad", album.title
        assert_equal "Indio Solari", album.artist
        assert_equal 2010, album.year
      end
    end

    test "whatever isn't a flac is ignored" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")
        touch("#{root}/A/1990 - B/notas.txt")
        touch("#{root}/A/1990 - B/01.mp3")

        assert_equal 1, source(root).albums.sole.tracks.size
      end
    end

    private

    # A fake tag reader: tags come from what the test declared, not from
    # reading the file. This way the scanner is tested without ffmpeg and without real FLACs.
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
          duration: tags.fetch(:duration, 1.0),
          audio: tags[:audio]
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
