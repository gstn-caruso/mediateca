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

  # A picture that arrived as bytes, put on disk so it can be measured.
  def kept(bytes)
    Rails.root.join("tmp/pictures-#{Process.pid}").tap { |dir| FileUtils.mkdir_p(dir) }
         .join("#{Digest::MD5.hexdigest(bytes)}.jpg").to_s
         .tap { |path| File.binwrite(path, bytes) }
  end
end
