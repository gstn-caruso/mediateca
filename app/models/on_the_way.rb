# A record on its way to the disk, drawn in the library as if it were already there
# — because in the only sense that matters, it is: somebody went and got it, and
# it is coming.
#
# Grey, with a clock, and a number that climbs. It cannot be played and it does not
# pretend it can. What it does is close the loop the rest of this app opened: the
# gap in the shelf is not just named any more, it is being filled, and you can
# watch it happen.
class OnTheWay
  Coming = Data.define(:artist, :title, :plays, :progress, :state)

  def initialize(profile)
    @profile = profile
  end

  # Everything the house is fetching, and how far along each of them is. Asked of
  # the torrent client, which is the only thing that knows — and if it cannot be
  # reached, the records still show, still grey, simply without a number.
  def all
    wanted = WantedRecord.on_the_way.order(plays: :desc).to_a
    return [] if wanted.empty?

    going = ask(wanted)

    wanted.map do |record|
      said = going.fetch(record.torrent_hash, {})

      Coming.new(artist: record.artist, title: record.title, plays: record.plays,
                 progress: said[:progress], state: said[:state])
    end
  end

  private

  def ask(wanted)
    return {} unless Qbittorrent.api.configured?

    Qbittorrent.api.progress(wanted.map(&:torrent_hash))
  rescue Qbittorrent::Api::Unreachable
    {}
  end
end
