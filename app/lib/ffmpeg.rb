require "open3"

# The only object that knows ffmpeg is a process. It answers with the pixels of
# an image; what to make of them belongs to whoever asked — Music::StrikingColour
# reads the record's colour out of them.
#
# ffmpeg is here already: the scanner reads every file's tags with ffprobe, which
# is the same package. A sleeve is a JPEG, decoding one is what ffmpeg does all
# day, and it costs nothing to ask it rather than to add a second image library
# to the image.
class Ffmpeg
  # ffmpeg is missing. Not the file's fault; ours.
  NotInstalled = Class.new(StandardError)

  # The file is not an image we can read — or not an image at all.
  Unreadable = Class.new(StandardError)

  CHANNELS = 3 # red, green, blue: rawvideo in rgb24 is three bytes a pixel

  # Sharp enough that a sleeve is a sleeve; 2 is nearly lossless and 31 is a
  # smear. The thumbnails are small, and the difference between 4 and 2 is bytes
  # nobody can see.
  QUALITY = 4

  # The image, decoded, scaled to a square of the size asked for, and handed back
  # as its bare pixels: no header, no container, nothing written to disk.
  def pixels(image, size:)
    raw = ask(image, %W[-frames:v 1 -vf scale=#{size}:#{size} -f rawvideo -pix_fmt rgb24 -])

    raw.unpack("C*").each_slice(CHANNELS).to_a
  end

  # The same image as a JPEG, fitted inside a square of the size asked for, its
  # shape kept — a photograph of an artist is not square and must not be made so.
  #
  # `min(iw, size)` rather than `size`, so a picture already smaller than the
  # square comes back the size it is: blowing one up would cost bytes to add
  # nothing. The commas are escaped because this is one filter argument, and a
  # comma is where ffmpeg would otherwise start reading the next filter.
  def thumbnail(image, size:)
    fit = "scale=w=min(iw\\,#{size}):h=min(ih\\,#{size}):force_original_aspect_ratio=decrease"

    ask(image, %W[-frames:v 1 -vf #{fit} -q:v #{QUALITY} -f mjpeg -])
  end

  private

  def ask(image, arguments)
    output, complaints, status = Open3.capture3(binary, "-v", "error", "-i", image.to_s, *arguments)
    raise Unreadable, "ffmpeg could not read #{image}: #{complaints.strip}" unless status.success?

    output
  rescue Errno::ENOENT
    raise NotInstalled, "can't find #{binary.inspect}: install ffmpeg or point FFMPEG at the binary"
  end

  def binary
    Rails.configuration.x.ffmpeg
  end
end
