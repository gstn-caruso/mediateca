require "test_helper"

module Music
  class ImporterTest < ActiveSupport::TestCase
    include SourceBuilders

    ENTORNO = "#{MUSIC_ROOT}/Almafuerte/1996 - Del entorno".freeze

    test "a source with no albums imports nothing" do
      Importer.new.import(source(albums: []))

      assert_equal 0, Artist.count
      assert_equal 0, Album.count
      assert_equal 0, Track.count
    end

    test "imports an album with its artist and its tracks" do
      Importer.new.import(source(albums: [ source_album(
        directory: ENTORNO,
        title: "Del entorno",
        artist: "Almafuerte",
        year: 1996,
        genre: "heavy metal",
        album_type: "album",
        disc_total: 1,
        cover_path: "#{ENTORNO}/cover.jpg",
        tracks: [ source_track(path: "#{ENTORNO}/01 - Vamos a la calle.flac", title: "Vamos a la calle", track_no: 1, duration: 200.5) ]
      ) ]))

      assert_equal "Almafuerte", Artist.sole.name

      album = Album.sole
      assert_equal ENTORNO, album.directory
      assert_equal "Del entorno", album.title
      assert_equal 1996, album.year
      assert_equal "heavy metal", album.genre
      assert_equal "album", album.album_type
      assert_equal 1, album.disc_total
      assert_equal "#{ENTORNO}/cover.jpg", album.cover_path
      assert_equal Artist.sole, album.artist

      track = Track.sole
      assert_equal "#{ENTORNO}/01 - Vamos a la calle.flac", track.path
      assert_equal "Vamos a la calle", track.title
      assert_equal 1, track.track_no
      assert_equal 1, track.disc_no
      assert_in_delta 200.5, track.duration
      assert_equal album, track.album
    end

    # The encoding a source measured is written onto the track, so the player can
    # show how good the file is without opening it again.
    test "a track's audio encoding is stored on it" do
      audio = Music::Audio.new(codec: "flac", bit_depth: 24, sample_rate: 96000, bit_rate: 2500000)
      Importer.new.import(source(albums: [ source_album(
        tracks: [ source_track(audio: audio) ]
      ) ]))

      track = Track.sole
      assert_equal "flac", track.codec
      assert_equal 24, track.bit_depth
      assert_equal 96000, track.sample_rate
      assert_equal 2500000, track.bit_rate
    end

    # Old rows scanned before we knew to look, and a source that never measured
    # (beets), both arrive without audio. That is not an error; the columns stay
    # empty until the next scan.
    test "a track with no audio is imported all the same" do
      Importer.new.import(source(albums: [ source_album(tracks: [ source_track(audio: nil) ]) ]))

      assert_nil Track.sole.codec
    end

    # The scan will run every time the library changes; importing the same
    # source twice can't duplicate anything.
    test "importing the same source twice doesn't duplicate anything" do
      albums = [ source_album(tracks: [ source_track ]) ]

      2.times { Importer.new.import(source(albums:)) }

      assert_equal 1, Artist.count
      assert_equal 1, Album.count
      assert_equal 1, Track.count
    end

    test "two albums by the same artist share a single artist row" do
      Importer.new.import(source(albums: [
        source_album(directory: GUANACO, title: "Mundo Guanaco", artist: "Almafuerte"),
        source_album(directory: ENTORNO, title: "Del entorno", artist: "Almafuerte")
      ]))

      assert_equal 1, Artist.count
      assert_equal 2, Album.count
      assert_equal [ "Almafuerte" ], Album.all.map { |album| album.artist.name }.uniq
    end

    # The directory is the identity: the album is the same even if its title,
    # year, or genre changed.
    test "reimporting a changed album updates it in place" do
      Importer.new.import(source(albums: [ source_album(directory: ENTORNO, title: "Del Entorno", year: 1996, genre: "") ]))
      Importer.new.import(source(albums: [ source_album(directory: ENTORNO, title: "Del entorno", year: 1997, genre: "heavy metal") ]))

      album = Album.sole
      assert_equal "Del entorno", album.title
      assert_equal 1997, album.year
      assert_equal "heavy metal", album.genre
    end

    # A track that got renamed on disk is a new track, and the old one is no
    # longer there. If they aren't cleaned up, the album accumulates ghosts that can't play.
    test "tracks the source no longer reports disappear from the album" do
      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - old.flac", track_no: 1),
        source_track(path: "#{GUANACO}/02 - stays.flac", track_no: 2)
      ]) ]))

      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/02 - stays.flac", track_no: 2)
      ]) ]))

      assert_equal [ "#{GUANACO}/02 - stays.flac" ], Track.pluck(:path)
    end

    # --- A song that moved is still the song ----------------------------------
    #
    # The path identifies a track, so a file renamed on disk arrives as a
    # stranger — and the row it replaces is destroyed, taking with it every
    # playlist that held the song, every heart, and everything ever played.
    # Nobody renames a file expecting their playlists to be emptied. So a
    # vanished track and an arriving one that are recognisably the same song are
    # the same row, moved.

    test "a track renamed on disk keeps the playlists, hearts and history it had" do
      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - Desencuetro.flac", title: "Desencuentro", track_no: 1)
      ]) ]))

      track = Track.sole
      profile = Profile.create!(name: "Gastón")
      playlist = profile.playlists.create!(name: "Asado")
      playlist.add(track)
      profile.like(track)
      profile.played(track)

      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - Desencuentro.flac", title: "Desencuentro", track_no: 1)
      ]) ]))

      assert_equal track.id, Track.sole.id
      assert_equal "#{GUANACO}/01 - Desencuentro.flac", Track.sole.path
      assert_equal [ track ], playlist.reload.tracks
      assert profile.likes?(track)
      assert_equal 1, profile.plays.count
    end

    # A folder renamed moves every song inside it, and the album is identified by
    # its directory — so without this the whole record, and every heart on it,
    # would be destroyed and rebuilt as a stranger.
    test "an album whose folder was renamed keeps its tracks, and the record keeps its hearts" do
      moved = "#{MUSIC_ROOT}/Almafuerte/1995 - Mundo Guanaco"

      Importer.new.import(source(albums: [ source_album(directory: GUANACO, tracks: [
        source_track(path: "#{GUANACO}/01 - Desencuentro.flac")
      ]) ]))

      album = Album.sole
      track = Track.sole
      profile = Profile.create!(name: "Gastón")
      profile.playlists.create!(name: "Asado").add(track)
      profile.like(album)

      Importer.new.import(source(albums: [ source_album(directory: moved, tracks: [
        source_track(path: "#{moved}/01 - Desencuentro.flac")
      ]) ]))

      assert_equal album.id, Album.sole.id
      assert_equal moved, Album.sole.directory
      assert_equal track.id, Track.sole.id
      assert profile.likes?(album)
      assert_equal [ track ], profile.playlists.sole.tracks
    end

    # Two songs that look alike are not evidence that either one moved. Guessing
    # wrong would hand a playlist a song nobody put there, which is worse than
    # losing the entry — so an ambiguous match is no match.
    test "two identical-looking songs are not re-keyed onto each other" do
      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - a.flac", title: "Intro", track_no: nil),
        source_track(path: "#{GUANACO}/02 - b.flac", title: "Intro", track_no: nil)
      ]) ]))

      Importer.new.import(source(albums: [ source_album(tracks: [
        source_track(path: "#{GUANACO}/01 - c.flac", title: "Intro", track_no: nil),
        source_track(path: "#{GUANACO}/02 - d.flac", title: "Intro", track_no: nil)
      ]) ]))

      assert_equal [ "#{GUANACO}/01 - c.flac", "#{GUANACO}/02 - d.flac" ], Track.order(:path).pluck(:path)
    end

    # An album deleted from the NAS can't keep appearing in the library.
    test "an album the source no longer reports disappears" do
      Importer.new.import(source(albums: [
        source_album(directory: GUANACO, title: "Mundo Guanaco"),
        source_album(directory: ENTORNO, title: "Del entorno")
      ]))

      Importer.new.import(source(albums: [ source_album(directory: GUANACO, title: "Mundo Guanaco") ]))

      assert_equal [ "Mundo Guanaco" ], Album.pluck(:title)
    end

    test "an artist left with no albums disappears" do
      Importer.new.import(source(albums: [ source_album(artist: "Almafuerte"), source_album(directory: ENTORNO, artist: "Hermética") ]))
      Importer.new.import(source(albums: [ source_album(artist: "Almafuerte") ]))

      assert_equal [ "Almafuerte" ], Artist.pluck(:name)
    end

    # Emptying the source by mistake can't empty the library: a NAS that
    # didn't mount looks exactly like a deleted library.
    test "an empty source doesn't wipe out the whole library" do
      Importer.new.import(source(albums: [ source_album ]))

      Importer.new.import(source(albums: []))

      assert_equal 1, Album.count
    end

    test "a multi-disc album's tracks end up ordered by disc and number" do
      Importer.new.import(source(albums: [ source_album(disc_total: 2, tracks: [
        source_track(path: "#{GUANACO}/CD2/01.flac", disc_no: 2, track_no: 1, title: "first of disc two"),
        source_track(path: "#{GUANACO}/CD1/01.flac", disc_no: 1, track_no: 1, title: "first of disc one"),
        source_track(path: "#{GUANACO}/CD1/02.flac", disc_no: 1, track_no: 2, title: "second of disc one")
      ]) ]))

      assert_equal [ [ 1, 1 ], [ 1, 2 ], [ 2, 1 ] ], Album.sole.tracks.map { |track| [ track.disc_no, track.track_no ] }
    end

    # 23 of the NAS's 75 albums have genre = '' and not NULL.
    test "an empty genre is stored as an empty string" do
      Importer.new.import(source(albums: [ source_album(genre: "") ]))

      assert_equal "", Album.sole.genre
    end

    test "an album with no cover is imported all the same" do
      Importer.new.import(source(albums: [ source_album(cover_path: nil) ]))

      assert_nil Album.sole.cover_path
    end
  end
end
