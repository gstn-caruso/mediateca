# How big a picture actually came out.
#
# Read off the file itself, with the same tool the app reads every other file
# with — a test that trusted the size it asked for would be testing the request
# rather than the answer.
module Pictures
  def measure(picture)
    stream = Ffprobe.new.describe(picture.to_s).fetch("streams").first

    [ stream["width"], stream["height"] ]
  end

  # The sharpest step anywhere in a picture: the biggest jump between two pixels
  # lying next to each other, sideways or up and down.
  #
  # An edge is what a picture is made of, and a blur is precisely the absence of
  # one — so this is how a test tells a picture from a light without looking at
  # it. Read off the pixels with the same tool the app reads every other file
  # with, at a size small enough that the reading is cheap.
  def steepest_edge(picture, across: 64)
    rows = Ffmpeg.new.pixels(picture.to_s, size: across).map(&:sum).each_slice(across).to_a

    sideways = rows.flat_map { |row| row.each_cons(2).map { |here, next_along| (here - next_along).abs } }
    downwards = rows.each_cons(2).flat_map { |above, below| above.zip(below).map { |up, down| (up - down).abs } }

    (sideways + downwards).max
  end

  # A picture that arrived as bytes, put on disk so it can be measured.
  def kept(bytes)
    Rails.root.join("tmp/pictures-#{Process.pid}").tap { |dir| FileUtils.mkdir_p(dir) }
         .join("#{Digest::MD5.hexdigest(bytes)}.jpg").to_s
         .tap { |path| File.binwrite(path, bytes) }
  end
end
