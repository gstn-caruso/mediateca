require "zlib"

# Sleeves, as real PNGs on a real disk.
#
# What the extractor does is read an image, so it is handed an image: bands of
# the colours asked for, in the proportions asked for. A test can then say what
# a record looks like — "half black, a quarter white, a quarter red", which is
# Figure 8 — and ask what colour the app should wear because of it.
module Sleeves
  SIZE = 64

  def sleeve(bands, size = SIZE)
    rows = bands.flat_map { |hex, share| [ Colour.hex(hex) ] * (size * share).round }
    rows.fill(rows.last, rows.size...size) if rows.size < size

    write(rows.take(size), size)
  end

  # The same bands, called what they are when the picture is of a person rather
  # than a record. The extractor cannot tell the difference, and neither can a
  # PNG; only the test that reads it can.
  alias_method :photograph, :sleeve

  # Where the pictures a test draws end up. One directory per process, because the
  # suite runs a worker per core and they would otherwise be writing sleeves over
  # each other's.
  #
  # A test that wants the app to actually SERVE one of these has to point the
  # media root at it: the root is the trust boundary, and a sleeve the app is not
  # allowed to read is refused before it is read — which is the whole point of it.
  def sleeves
    Rails.root.join("tmp/sleeves-#{Process.pid}").tap { |dir| FileUtils.mkdir_p(dir) }
  end

  private

  def write(rows, size)
    pixels = rows.map { |colour| 0.chr + ([ colour.red, colour.green, colour.blue ].pack("C3") * size) }.join
    png = "\x89PNG\r\n\x1a\n".b + chunk("IHDR", header(size)) + chunk("IDAT", Zlib::Deflate.deflate(pixels)) + chunk("IEND", "")

    sleeves.join("#{Digest::MD5.hexdigest(png)}.png").to_s.tap { |path| File.binwrite(path, png) }
  end

  def header(size)
    [ size, size ].pack("NN") + [ 8, 2, 0, 0, 0 ].pack("C5") # 8-bit truecolour, no interlacing
  end

  def chunk(type, data)
    [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
  end
end
