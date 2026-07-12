# An ffprobe that answers with a description we wrote ourselves, so reading tags
# is tested against every shape a file can have — including the ones we have no
# file for — without the binary, and without a file.
class FakeFfprobe
  def initialize(streams: [], format: {})
    @description = { "streams" => streams, "format" => format }
  end

  def describe(_path)
    @description
  end
end
