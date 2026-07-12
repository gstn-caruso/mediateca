module Music
  # The whole music library, as one source to import from.
  #
  # The disk decides what exists: 270 of the NAS's FLACs are not in beets, and
  # beets holds three System of a Down albums whose files it lost. beets decides
  # what things are called, because it knows better than a filename — except for
  # the cover, where it picked the back of the sleeve for every Almafuerte
  # record.
  class Library
    def initialize(disk:, beets: nil)
      @disk = disk
      @beets = beets
    end

    def albums
      known = beets ? beets.albums.index_by(&:directory) : {}

      disk.albums.map { |album| enrich(album, known[album.directory]) }
    end

    private

    attr_reader :disk, :beets

    def enrich(album, known)
      return album unless known

      album.with(
        title: better(known.title, album.title),
        artist: better(known.artist, album.artist),
        year: better(known.year, album.year),
        album_type: better(known.album_type, album.album_type),
        disc_total: [ known.disc_total.to_i, album.disc_total.to_i ].max,
        tracks: retitle(album.tracks, known.tracks)
      )
    end

    # Only a track the disk still has can be played, however much beets
    # remembers about the others.
    def retitle(tracks, known_tracks)
      known = known_tracks.index_by(&:path)

      tracks.map do |track|
        found = known[track.path]
        found ? track.with(title: better(found.title, track.title)) : track
      end
    end

    def better(known, ours)
      known.presence || ours
    end
  end
end
