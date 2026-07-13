# An ffprobe that answers with a description we wrote ourselves, so reading tags
# is tested against every shape a file can have — including the ones we have no
# file for — without the binary, and without a file.
#
# It also remembers whether it was ever asked to count frames: a lossless file is
# not supposed to be, and the only way to tell is to watch.
class FakeFfprobe
  attr_reader :frames_counted

  def initialize(streams: [], format: {}, frame_sizes: [])
    @description = { "streams" => streams, "format" => format }
    @frame_sizes = frame_sizes
    @frames_counted = false
  end

  def describe(_path)
    @description
  end

  def frame_sizes(_path)
    @frames_counted = true
    @frame_sizes
  end
end
