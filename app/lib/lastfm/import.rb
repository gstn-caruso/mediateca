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

    def bring_the_history
      each_page { Lastfm.api.recent_tracks(user:, page: it) }.each_slice(500) do |songs|
        file(songs.filter_map { |song| play(song) })
      end
    end

    def bring_the_hearts
      hearted = each_page { Lastfm.api.loved_tracks(user:, page: it) }.filter_map { known(it) }

      @hearts = Like.insert_all(
        hearted.uniq.map { { profile_id: @profile.id, likeable_type: "Track", likeable_id: it, created_at: Time.current, updated_at: Time.current } },
        unique_by: %i[profile_id likeable_type likeable_id]
      ).count if hearted.any?
    end

    # Written straight into the table: a play that came from Last.fm has no
    # business being sent back to it, and going through the front door would send
    # every one of them.
    def file(plays)
      return if plays.empty?

      @found += Play.insert_all(plays, unique_by: %i[profile_id track_id played_at]).count
    end

    def play(song)
      track_id = known(song) or return nil
      now = Time.current

      { profile_id: @profile.id, track_id:, played_at: song.fetch(:at), created_at: now, updated_at: now }
    end

    # A song Last.fm knows and this house does not. Counted, and said out loud —
    # an import that quietly found a tenth of a history and called it done is
    # worse than one that never ran.
    def known(song)
      found = @library.find(artist: song[:artist], track: song[:track])
      @strangers += 1 unless found

      found
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
