# What the torrent client has actually done with what it was handed.
#
# A record on the way shows up in the library at once — grey, with a clock, and a
# number that goes up. This is what moves the number. When the download finishes,
# the nightly scan is what turns it into a real record; this only stops calling it
# a want.
class WatchTheChaseJob < ApplicationJob
  queue_as :default

  def perform
    on_the_way = WantedRecord.on_the_way.to_a
    return if on_the_way.empty? || !Qbittorrent.api.configured?

    said = Qbittorrent.api.progress(on_the_way.map(&:torrent_hash))

    on_the_way.each do |wanted|
      going = said[wanted.torrent_hash] or next
      next unless going.fetch(:progress) >= 100

      wanted.update!(found_at: Time.current)
    end

    # It is on the disk now, and the disk is the truth. Nothing is a record here
    # until the scan has read its tags.
    ScanMusicJob.perform_later if said.values.any? { it.fetch(:progress) >= 100 }
  rescue Qbittorrent::Api::Unreachable
    nil
  end
end
