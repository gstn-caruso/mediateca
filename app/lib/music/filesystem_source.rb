module Music
  # The music as the disk has it. Every FLAC counts, whether or not beets ever
  # heard of it — and on the NAS, 270 of them it never did.
  #
  # The library is laid out as Artist/Album/track.flac, and 97 of the 1171
  # tracks hang one level deeper, inside a CD01 or CD02. So an album is the
  # directory two levels below the root, and its tracks are every FLAC under it.
  class FilesystemSource
    EXTENSION = ".flac".freeze

    # A cover, never a back cover. beets picked `cover.1.jpg` for the six
    # Almafuerte albums, and it is byte for byte the same file as their
    # "Cover back.jpg".
    COVERS = [ "cover.jpg", "cover.jpeg", "cover.png", "folder.jpg", "front.jpg", "cover front.jpg" ].freeze
    NOT_A_COVER = /\b(back|cd|disc|inside|inlay)\b/i

    IMAGES = %w[.jpg .jpeg .png].freeze

    # Album folders read "2010 - El perfume de la tempestad".
    LEADING_YEAR = /\A(\d{4})\s*-\s*/

    def initialize(root:, tags: Tags.new)
      @root = ::File.realpath(root.to_s)
      @tags = tags
    end

    def albums
      tracks_by_album.filter_map { |directory, paths| album(directory, paths) }
    end

    private

    attr_reader :root, :tags

    def tracks_by_album
      ::Dir.glob("**/*", base: root)
           .select { |relative| flac?(relative) }
           .group_by { |relative| album_directory(relative) }
           .transform_values { |relatives| relatives.map { |relative| ::File.join(root, relative) }.sort }
    end

    def flac?(relative)
      ::File.extname(relative).downcase == EXTENSION
    end

    # Artist/Album, however deep the track itself sits. A file shallower than
    # that has no album folder to belong to, so it belongs to its own.
    def album_directory(relative)
      trail = relative.split("/")

      ::File.join(root, *(trail.size > 2 ? trail.first(2) : trail.first(trail.size - 1)))
    end

    def album(directory, paths)
      read = readable(paths)
      return if read.empty?

      sung = read.values

      Source::Album.new(
        directory: directory,
        title: common(sung, :album) || titled(directory),
        artist: common(sung, :album_artist) || common(sung, :artist) || ::File.basename(::File.dirname(directory)),
        year: common(sung, :year) || year_of(directory),
        genre: common(sung, :genre),
        album_type: nil,
        disc_total: sung.map(&:disc_no).max || 1,
        cover_path: cover_in(directory),
        tracks: tracks_from(read)
      )
    end

    # One file lands truncated over SMB and the whole scan used to die on it: the
    # nightly job failed in silence, and no music ever appeared again — the
    # library held hostage by one bad copy. A file nothing can read is a file
    # nothing can play, so the scan steps over it and says so in the log.
    #
    # Only the unreadable file is stepped over. A missing binary is not a bad
    # file, it is a broken install, and swallowing that would skip everything
    # and call the library empty.
    def readable(paths)
      paths.filter_map do |path|
        [ path, tags.read(path) ]
      rescue ::Ffprobe::Unreadable => e
        Rails.logger.warn("Skipping #{path}: #{e.message}")
        nil
      end.to_h
    end

    def tracks_from(read)
      read.map { |path, tags| Source::Track.new(path:, title: tags.title, artist: tags.artist, track_no: tags.track_no, disc_no: tags.disc_no, duration: tags.duration, audio: tags.audio) }
          .sort_by { |track| [ track.disc_no, track.track_no || 0, track.path ] }
    end

    # One badly tagged track should not rename the album. The value most of its
    # tracks agree on wins.
    def common(sung, field)
      sung.filter_map(&field).tally.max_by { |_value, count| count }&.first
    end

    def titled(directory)
      ::File.basename(directory).sub(LEADING_YEAR, "")
    end

    def year_of(directory)
      ::File.basename(directory)[LEADING_YEAR, 1]&.to_i
    end

    def cover_in(directory)
      images = ::Dir.children(directory).select { |name| IMAGES.include?(::File.extname(name).downcase) }
      chosen = named_like_a_cover(images) || anything_but_a_back(images)

      chosen && ::File.join(directory, chosen)
    end

    def named_like_a_cover(images)
      images.select { |name| COVERS.include?(name.downcase) }
            .min_by { |name| COVERS.index(name.downcase) }
    end

    def anything_but_a_back(images)
      images.sort.find { |name| !name.match?(NOT_A_COVER) }
    end
  end
end
