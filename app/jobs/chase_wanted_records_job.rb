# Goes and gets the records this house plays and does not have.
#
# It fires on its own, and the reason it can be trusted to is that it walks. The
# want list is thousands of records long and would be a hundred gigabytes off the
# leash — so it takes three at a time, heaviest want first, and comes back in half
# an hour for the next three. It will get there.
#
# Every record is sought exactly once. A record nobody could find is not a record
# to go looking for every half hour forever, and what could not be found is written
# down and said out loud rather than left as a silence.
class ChaseWantedRecordsJob < ApplicationJob
  queue_as :default

  # One clear winner, or none. A search that turns up an original, a deluxe, a
  # remaster and a vinyl rip has not answered the question — it has asked one, and
  # a machine has no business guessing which edition somebody meant. Those wait on
  # the page for a human to point.
  CLEARLY = 4.0

  def perform
    return unless Qbittorrent.api.configured?

    # The want list is kept up to date whether or not anything is being fetched:
    # knowing what is missing is worth having on its own, and it is what the report
    # and the shelf are drawn from. It is only the *fetching* that the disk stops.
    Profile.joins(:scrobbler).find_each { WantedRecord.refresh_from(it) }

    disk = Disk.holding_the_music
    return Rails.logger.info(disk.why_not) unless disk.room?

    WantedRecord.unsought.limit(WantedRecord::A_FEW).each { chase(it) }
  end

  private

  def chase(wanted)
    found = Qbittorrent.api.search(wanted.as_a_search)

    return wanted.sought(nothing_doing: "Nobody is seeding a lossless copy.") if found.empty?
    return wanted.sought(nothing_doing: "#{found.size} editions, and no way to tell which one you meant.") unless one_of_them?(found)

    best = found.first
    Qbittorrent.api.add(best.fetch(:magnet), into: wanted.shelf_for)
    wanted.sought(hash: best.fetch(:hash), name: best.fetch(:name))
  rescue Qbittorrent::Api::Unreachable => e
    # The client is off, or the NAS cannot reach it. Not the record's fault: it
    # stays unsought, and the next sweep tries again.
    Rails.logger.warn "Chasing #{wanted.as_a_search}: #{e.message}"
  end

  # Obvious means obvious: the leader has four times the seeders of whatever is
  # behind it. Anything closer is a choice, and a choice is not ours to make.
  def one_of_them?(found)
    found.one? || found.first.fetch(:seeders) >= found.second.fetch(:seeders) * CLEARLY
  end
end
