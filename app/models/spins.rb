# Every turn this listener ever gave every record, worked out from the top.
#
# While plays arrive in the order they are heard, a turn can be spotted as it
# happens — one play at a time, three questions to the database, done. An import
# does not arrive that way. It files a decade of listening this morning, out of
# order among itself, so the song that interrupts a record can land in the table
# *after* the record it interrupted. Nothing can be judged as it arrives.
#
# So after an import the turns are counted again, from the top: one pass over the
# whole history, in the order it was heard. It is the same rule the live path
# uses, and a test holds the two to it.
class Spins
  def initialize(profile)
    @profile = profile
  end

  def recount
    Spin.transaction do
      @profile.spins.delete_all
      turns.each_slice(500) { Spin.insert_all(it) }
    end
  end

  private

  # A record turns when every song on it has been heard with nothing else put on
  # in between. Anything else ends the run — and so does the turn itself, whose
  # songs are finished business: what comes after starts the next one.
  def turns
    now = Time.current
    on = nil
    heard = Set.new

    history.filter_map do |play_id, album_id, track_id|
      heard = Set.new if album_id != on
      on = album_id
      heard << track_id

      next unless heard == songs_on(album_id)

      heard = Set.new
      { profile_id: @profile.id, album_id:, play_id:, created_at: now, updated_at: now }
    end
  end

  # By the clock, and the row number only to break a tie — two songs heard in the
  # same second are still in the order they were put on.
  def history
    @profile.plays.joins(:track)
            .order(:played_at, :id)
            .pluck("plays.id", "tracks.album_id", "tracks.id")
  end

  def songs_on(album_id)
    @songs_on ||= Track.pluck(:album_id, :id).group_by(&:first).transform_values { |on| on.map(&:last).to_set }

    @songs_on.fetch(album_id, Set.new)
  end
end
