module Spotify
  # What a listener kept on Spotify, brought home: the songs they hearted, the
  # records they saved, and the lists they made.
  #
  # Not their listening. Spotify has no endpoint for a history and never has had
  # one — the most it will tell you is the last fifty songs you played, and no
  # amount of asking politely changes that. A history lives on Last.fm, and that is
  # where Mediateca goes for it.
  #
  # The hearts are written straight into the table rather than given through the
  # front door, which would queue every one of them to be loved on Last.fm too. A
  # heart you gave on Spotify years ago is not a heart you are giving now.
  class Import
    def initialize(profile)
      @profile = profile
      @library = Music::Lookup.new
      @hearts = 0
      @lists = 0
      @strangers = 0
    end

    def bring_it_all_home
      token = @profile.spotify_account.token

      hearts_for(Spotify.api.saved_tracks(token:))
      records_for(Spotify.api.saved_albums(token:))
      lists_from(token)

      @profile.spotify_account.imported(hearts: @hearts, lists: @lists, strangers: @strangers)
    end

    private

    def hearts_for(songs)
      keep(songs.filter_map { known(it) }, "Track")
    end

    # A record hearted on Spotify is a record hearted here — Mediateca hearts both
    # songs and sleeves, which is the one place its idea of a heart is bigger than
    # Last.fm's.
    def records_for(records)
      keep(records.filter_map { known_record(it) }, "Album")
    end

    def keep(ids, kind)
      return if ids.empty?

      now = Time.current
      @hearts += Like.insert_all(
        ids.uniq.map { { profile_id: @profile.id, likeable_type: kind, likeable_id: it, created_at: now, updated_at: now } },
        unique_by: %i[profile_id likeable_type likeable_id]
      ).count
    end

    # A list is a list: the songs of it this house owns, in the order they were put
    # there. A list that lands empty is not made — an empty playlist named after
    # one you cannot play is worse than no playlist.
    def lists_from(token)
      Spotify.api.playlists(token:).each do |list|
        songs = Spotify.api.playlist_songs(list.fetch(:id), token:).filter_map { known(it) }
        next if songs.empty?

        fill(list.fetch(:name), songs)
        @lists += 1
      end
    end

    def fill(name, songs)
      list = @profile.playlists.find_or_create_by!(name:)
      list.entries.destroy_all

      now = Time.current
      PlaylistEntry.insert_all(
        songs.each_with_index.map { |track_id, at| { playlist_id: list.id, track_id:, position: at + 1, created_at: now, updated_at: now } }
      )
    end

    def known(song)
      found = @library.find(artist: song[:artist], track: song[:track])
      @strangers += 1 unless found

      found
    end

    def known_record(record)
      Album.joins(:artist)
           .where("LOWER(albums.title) = ? AND LOWER(artists.name) = ?", record[:title].to_s.downcase, record[:artist].to_s.downcase)
           .pick(:id)
    end
  end
end
