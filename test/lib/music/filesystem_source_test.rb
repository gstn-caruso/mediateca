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
          title: "Satelital", track_no: 5, duration: 266.4)

        album = source(root).albums.sole

        assert_equal "#{root}/Indio Solari/2010 - El perfume de la tempestad", album.directory
        assert_equal "El perfume de la tempestad", album.title
        assert_equal "Indio Solari", album.artist
        assert_equal 2010, album.year
        assert_equal 1, album.disc_total

        track = album.tracks.sole
        assert_equal "Satelital", track.title
        assert_equal 5, track.track_no
        assert_in_delta 266.4, track.duration
      end
    end

    # Whom the file credits the song to. Almost always the album's artist, and
    # 36 times in 1171 somebody else — the scanner is not the one to decide that.
    test "a track carries the artist its file credits" do
      within_root do |root|
        create(root, "Charly García/1984 - Piano Bar/05.flac",
          album_artist: "Charly García", artist: "Luis Alberto Spinetta, Pedro Aznar y Charly García")

        assert_equal "Luis Alberto Spinetta, Pedro Aznar y Charly García", source(root).albums.sole.tracks.sole.artist
      end
    end

    # The scanner carries a file's encoding through untouched, so the catalog can
    # record how good the file is, not just what it's called.
    test "a track carries the audio its file was encoded with" do
      within_root do |root|
        flac = Audio.new(codec: "flac", bit_depth: 16, sample_rate: 44100, bit_rate: 1006840)
        create(root, "Indio Solari/2010 - X/01.flac", audio: flac)

        assert_equal flac, source(root).albums.sole.tracks.sole.audio
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

    test "whatever isn't audio is ignored" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac")
        touch("#{root}/A/1990 - B/notas.txt")
        touch("#{root}/A/1990 - B/cover.jpg")

        assert_equal 1, source(root).albums.sole.tracks.size
      end
    end

    # Not every album exists in FLAC. Two of the NAS's — Tokischa and Neutro
    # Shorty — were never released to a tracker at all, and the only copy there
    # is came off YouTube as Opus. A lossy album is still an album; wrapping it
    # in FLAC to get it counted would only be a lie about its fidelity.
    test "an album the library only has in a lossy format is still an album" do
      within_root do |root|
        create(root, "Neutro Shorty/2026 - El disco de salsa/01 - Yo soy.opus",
          album: "El disco de salsa", album_artist: "Neutro Shorty", year: 2026, title: "Yo soy")

        album = source(root).albums.sole

        assert_equal "El disco de salsa", album.title
        assert_equal "Yo soy", album.tracks.sole.title
      end
    end

    # Nothing says an album is of one format. A FLAC rip missing a bonus track
    # that only YouTube has ends up holding both.
    test "an album mixing formats counts every one of them" do
      within_root do |root|
        create(root, "A/1990 - B/01.flac", track_no: 1)
        create(root, "A/1990 - B/02.opus", track_no: 2)
        create(root, "A/1990 - B/03.mp3", track_no: 3)

        assert_equal 3, source(root).albums.sole.tracks.size
      end
    end

    # One file lands truncated over SMB. Without this the scan dies on it, the
    # nightly job fails in silence, and no music ever appears again — the whole
    # library held hostage by one bad copy. A file nothing can read is a file
    # nothing can play, so the scan steps over it and carries on.
    test "a file that cannot be read is skipped, and the rest of the album still scans" do
      within_root do |root|
        create(root, "A/1990 - B/01 - Good.flac", title: "Good")
        unreadable(create(root, "A/1990 - B/02 - Truncated.flac"))

        assert_equal [ "Good" ], source(root).albums.sole.tracks.map(&:title)
      end
    end

    test "an album whose every file is unreadable is no album at all" do
      within_root do |root|
        unreadable(create(root, "A/1990 - B/01.flac"))

        assert_empty source(root).albums
      end
    end

    private

    # A fake tag reader: tags come from what the test declared, not from
    # reading the file. This way the scanner is tested without ffmpeg and without real FLACs.
    class DeclaredTags
      def initialize
        @by_path = {}
        @unreadable = []
      end

      def declare(path, **tags) = @by_path[path] = tags

      def cannot_read(path) = @unreadable << path

      def read(path)
        raise Ffprobe::Unreadable, "ffprobe could not read #{path}" if @unreadable.include?(path)

        tags = @by_path.fetch(path, {})

        Music::FileTags.new(
          title: tags.fetch(:title, File.basename(path, ".*")),
          artist: tags[:artist],
          album_artist: tags[:album_artist],
          album: tags[:album],
          year: tags[:year],
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

    # A file that landed truncated: it is there, and nothing can read it.
    def unreadable(path)
      @tags.cannot_read(path)
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
