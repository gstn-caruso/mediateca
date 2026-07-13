# How full the disk the music lives on is.
#
# A library that fills its own disk stops being one. There is nowhere left for the
# records already on it to grow, no room for the scan, the database or the machine
# itself — and a NAS with no free space does not degrade politely, it stops. So
# there is a line, and nothing is fetched past it.
#
# Asked of the disk itself rather than of the torrent client: the client knows how
# much room is left where *it* writes, and this is a question about the shelf.
class Disk
  # Past this, the chase stops. Not a suggestion — nothing is fetched at all.
  FULL_ENOUGH = ENV.fetch("MEDIATECA_DISK_LIMIT", 60).to_i

  # One place the app asks how full the disk is, so one place a test can answer in
  # its stead. Built fresh each time it is asked: a long-running process outlives
  # the answer, and a disk that had room this morning is exactly the disk that
  # fills up.
  class << self
    attr_writer :holding_the_music

    def holding_the_music
      @holding_the_music || new(Rails.configuration.x.music_root)
    end
  end

  def initialize(path)
    @path = path
  end

  # How full it is, as a whole number, or nothing at all if the disk cannot be
  # asked. A disk that will not answer is not a disk to start filling.
  def used
    @used ||= said&.fetch(:used)
  end

  def free_bytes = said&.fetch(:free)

  def room?
    used.present? && used < FULL_ENOUGH
  end

  # The one sentence the app says out loud when it is not fetching anything, so
  # that "nothing is being fetched" is never a silence.
  def why_not
    return "The disk can't be read, so nothing is being fetched." if used.nil?

    "The disk is #{used}% full — past the #{FULL_ENOUGH}% line, so nothing is being fetched."
  end

  private

  # `df -Pk`, which is POSIX and says the same thing on every machine this could
  # possibly run on. The header is one line and the answer is the next.
  def said
    return @said if defined?(@said)

    @said = read
  end

  def read
    out = `df -Pk #{Shellwords.escape(@path.to_s)} 2>/dev/null`
    row = out.lines[1]&.split
    return nil unless row && row.size >= 5

    { used: row[4].to_i, free: row[3].to_i * 1024 }
  rescue SystemCallError, Errno::ENOENT
    nil
  end
end
