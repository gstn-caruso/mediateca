module Lastfm
  # Everything Last.fm has been keeping for this listener, brought home: the years
  # of listening that happened before this library existed, and the hearts they
  # gave elsewhere.
  #
  # It matters that none of it goes back out again. These plays came *from*
  # Last.fm, so they are written straight into the table rather than through the
  # front door — which would queue every one of them to be scrobbled back, and
  # hand Last.fm a hundred thousand songs it told us about itself.
  #
  # And it is slow on purpose. A history of 127,000 scrobbles is 637 pages, and
  # Last.fm suspends accounts that ask "several times a second". So it asks once a
  # second, takes a quarter of an hour, and nobody waits on it.
  class Import
    A_DECENT_PAUSE = 1

    # How many plays are written in one statement.
    BREATH = 500

    # Where these came from, so nothing ever tells them back to the place that
    # told us.
    SOURCE = "lastfm".freeze

    def initialize(profile, pause: A_DECENT_PAUSE)
      @profile = profile
      @pause = pause
      @library = Music::Lookup.new
      @found = 0
      @hearts = 0
      @strangers = 0
    end

    def bring_it_all_home
      bring_the_hearts
      bring_the_history

      # The turns cannot be spotted as they arrive — an import files a decade this
      # morning, out of order, so the song that interrupts a record can land after
      # the record it interrupted. They are counted again, from the top.
      Spins.new(@profile).recount

      @profile.scrobbler.imported(plays: @found, hearts: @hearts, strangers: @strangers)
    end

    private

    # The whole of it, and not only the part of it this house owns a copy of.
    #
    # It used to keep the songs it could match and throw the rest away — which, for
    # a hundred thousand scrobbles matched against a few thousand records, is most
    # of a life. The songs that are not here become gaps, and a gap is a thing a
    # play can be of: a history of only what is on your disk is a history of the
    # wrong life.
    def bring_the_history
      each_page { Lastfm.api.recent_tracks(user:, page: it) }.each_slice(BREATH) do |songs|
        file(songs.map { |song| play(song) })
      end
    end

    def bring_the_hearts
      hearted = each_page { Lastfm.api.loved_tracks(user:, page: it) }.filter_map { known(it) }

      @hearts = Like.insert_all(
        hearted.uniq.map { { profile_id: @profile.id, likeable_type: "Track", likeable_id: it, created_at: Time.current, updated_at: Time.current } },
        unique_by: %i[profile_id likeable_type likeable_id]
      ).count if hearted.any?
    end

    # Written straight into the table rather than through the front door, which
    # would queue every one of them to be scrobbled back — and hand Last.fm a
    # hundred thousand songs it told us about itself. They are marked with where
    # they came from, so nothing here ever mistakes them for listening done here.
    #
    # Two statements for a page of two hundred, not two hundred: a life is a lot of
    # rows, and going one at a time is how an import takes all afternoon.
    def file(plays)
      ours, theirs = plays.compact.partition { it[:track_id] }

      @found += insert(ours, unique_by: %i[profile_id track_id played_at])
      @found += insert(theirs, unique_by: %i[profile_id absence_id played_at])
    end

    def insert(rows, unique_by:)
      return 0 if rows.empty?

      Play.insert_all(rows, unique_by:).count
    end

    def play(song)
      now = Time.current
      track_id = @library.find(artist: song[:artist], track: song[:track])

      { profile_id: @profile.id, track_id:, absence_id: track_id ? nil : gap_for(song),
        played_at: song.fetch(:at), source: SOURCE, created_at: now, updated_at: now }
    end

    # A song Last.fm knows and this house has no copy of. It is not thrown away any
    # more — it is a gap, and a gap is a thing that can be listened to, counted and
    # shown. There are tens of thousands of them in a life, so they are looked up in
    # memory and written in batches: create_or_find_by, a hundred thousand times, is
    # an afternoon.
    def gap_for(song)
      @strangers += 1
      key = [ song[:artist].to_s, song[:track].to_s ]

      gaps[key] ||= Absence.create!(profile: @profile, artist: key.first, title: key.last).id
    end

    def gaps
      @gaps ||= @profile.absences.pluck(:artist, :title, :id).to_h { |artist, title, id| [ [ artist, title ], id ] }
    end

    # For the hearts, which are few and which only make sense for a song you have.
    def known(song)
      @library.find(artist: song[:artist], track: song[:track])
    end

    def each_page
      page = 1

      Enumerator.new do |all|
        loop do
          said = yield(page)
          said.fetch(:songs).each { all << it }

          break if page >= said.fetch(:pages)

          page += 1
          sleep @pause
        end
      end
    end

    def user = @profile.scrobbler.username
  end
end
