require "zlib"

# Sleeves, as real PNGs on a real disk.
#
# What the extractor does is read an image, so it is handed an image: bands of
# the colours asked for, in the proportions asked for. A test can then say what
# a record looks like — "half black, a quarter white, a quarter red", which is
# Figure 8 — and ask what colour the app should wear because of it.
module Sleeves
  SIZE = 64

  def sleeve(bands)
    rows = bands.flat_map { |hex, share| [ Colour.hex(hex) ] * (SIZE * share).round }
    rows.fill(rows.last, rows.size...SIZE) if rows.size < SIZE

    write(rows.take(SIZE))
  end

  # The same bands, called what they are when the picture is of a person rather
  # than a record. The extractor cannot tell the difference, and neither can a
  # PNG; only the test that reads it can.
  alias_method :photograph, :sleeve

  private

  def write(rows)
    pixels = rows.map { |colour| 0.chr + ([ colour.red, colour.green, colour.blue ].pack("C3") * SIZE) }.join
    png = "\x89PNG\r\n\x1a\n".b + chunk("IHDR", header) + chunk("IDAT", Zlib::Deflate.deflate(pixels)) + chunk("IEND", "")

    sleeves.join("#{Digest::MD5.hexdigest(png)}.png").to_s.tap { |path| File.binwrite(path, png) }
  end

  def header
    [ SIZE, SIZE ].pack("NN") + [ 8, 2, 0, 0, 0 ].pack("C5") # 8-bit truecolour, no interlacing
  end

  def chunk(type, data)
    [ data.bytesize ].pack("N") + type + data + [ Zlib.crc32(type + data) ].pack("N")
  end

  # One directory per process, because the suite runs a worker per core and they
  # would otherwise be writing sleeves over each other's.
  def sleeves
    Rails.root.join("tmp/sleeves-#{Process.pid}").tap { |dir| FileUtils.mkdir_p(dir) }
  end
end
