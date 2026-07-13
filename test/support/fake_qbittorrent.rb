# The house's torrent client, without the house's torrent client.
class FakeQbittorrent
  attr_reader :added, :searched

  def initialize(configured: true)
    @configured = configured
    @finds = {}
    @going = {}
    @added = []
    @searched = []
  end

  def configured? = @configured

  # What the world is seeding, as far as this test is concerned.
  def seeding(query, *editions)
    @finds[query] = editions
    self
  end

  def going(hash, progress)
    @going[hash] = { progress:, state: "downloading", name: hash }
    self
  end

  def search(query)
    @searched << query
    @finds.fetch(query, []).sort_by { -it.fetch(:seeders) }
  end

  def add(magnet, into:, as: "mediateca")
    @added << { magnet:, into: }
  end

  def progress(hashes)
    @going.slice(*hashes)
  end

  # The client is off, or the NAS cannot reach it.
  class Unreachable < FakeQbittorrent
    def search(*) = raise(Qbittorrent::Api::Unreachable, "no route to host")
    def progress(*) = raise(Qbittorrent::Api::Unreachable, "no route to host")
  end
end
