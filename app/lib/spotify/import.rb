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
      @refused = 0

      # A set, not a tally: one song you do not own is one gap, however many of
      # your lists it turns up in.
      @strangers = Set.new
    end

    def bring_it_all_home
      token = @profile.spotify_account.token

      hearts_for(Spotify.api.saved_tracks(token:))
      records_for(Spotify.api.saved_albums(token:))
      lists_from(token)

      @profile.spotify_account.imported(hearts: @hearts, lists: @lists, strangers: @strangers.size, refused: @refused)
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

    # A list you kept somewhere else is the list you kept. Handing back only the
    # songs this house happens to own would be a shorter list that never said why —
    # so the whole thing comes home, and the songs that are not here come as gaps:
    # grey, unplayable, and named.
    #
    # Spotify will not hand over every list it names — one made by somebody else,
    # one it has decided this app may not read. It answers 403 and it is entitled
    # to. One refusal is not a reason to throw an import away: the hearts already
    # home stay home, the other lists still come, and the one that was refused is
    # counted and said out loud.
    def lists_from(token)
      Spotify.api.playlists(token:).each do |list|
        lines = Spotify.api.playlist_songs(list.fetch(:id), token:).map { line_for(it) }
        next if lines.empty?

        fill(list.fetch(:name), lines)
        @lists += 1
      rescue Api::Refused
        @refused += 1
      end
    end

    # A line in a list: the song, or the gap where it should be. Both keys on every
    # line, one of them empty — insert_all writes one statement for the lot, and one
    # statement has one shape.
    def line_for(song)
      track_id = @library.find(artist: song[:artist], track: song[:track])

      { track_id:, absence_id: track_id ? nil : missed(song).id }
    end

    def fill(name, lines)
      list = @profile.playlists.find_or_create_by!(name:)
      list.entries.destroy_all

      now = Time.current
      PlaylistEntry.insert_all(
        lines.each_with_index.map { |line, at| line.merge(playlist_id: list.id, position: at + 1, created_at: now, updated_at: now) }
      )
    end

    def known(song)
      found = @library.find(artist: song[:artist], track: song[:track])
      missed(song) if found.nil?

      found
    end

    # The names the import used to count and then throw away — a thousand songs
    # somebody loves, and the app could not name one of them.
    def missed(song)
      @strangers << [ song[:artist], song[:track] ]

      @profile.misses(artist: song[:artist].to_s, title: song[:track].to_s)
    end

    def known_record(record)
      Album.joins(:artist)
           .where("LOWER(albums.title) = ? AND LOWER(artists.name) = ?", record[:title].to_s.downcase, record[:artist].to_s.downcase)
           .pick(:id)
    end
  end
end
