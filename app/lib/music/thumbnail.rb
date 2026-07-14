require "fileutils"

module Music
  # A picture at the size it is going to be drawn.
  #
  # A sleeve on the NAS is a scan: fifteen hundred pixels square, a megabyte or
  # two of them. The library rail draws it at forty-four. It was sending the scan
  # anyway — seventy-five of them, on the first page a listener opens — and a
  # phone had to download every byte and then decode it into memory it does not
  # have. Nothing about the picture on screen was any better for it.
  #
  # So a picture is drawn once at each size the app actually uses, kept on disk
  # beside the portraits, and handed out from there. Which sizes those are is a
  # list and not a number out of the URL: a URL that can ask for any size is a URL
  # that can ask the NAS to draw ten thousand of them.
  class Thumbnail
    # 96 for the rows and the pill (a 44px row on a retina phone), 320 for a tile
    # in a grid, 640 for the sleeve at the top of a record's own page, and 64 for
    # the wash behind a title, which is a picture blown up until it is only light.
    SIZES = [ 64, 96, 320, 640 ].freeze

    # The picture at this size, or nothing at all — and nothing is an answer:
    # whoever asked has the original, which is what they used to send.
    def self.of(picture, size:)
      return unless picture.present? && SIZES.include?(size.to_i)

      new(picture.to_s, size: size.to_i).path
    end

    def self.root
      Rails.configuration.x.thumbnails_root
    end

    def initialize(picture, size:)
      @picture = picture
      @size = size
    end

    # A record gets re-ripped, or moved, or thrown away, and the catalog goes on
    # holding the path it used to be at — with a thumbnail of it still sitting on
    # disk, drawn back when the file was there. Asking when a picture that is not
    # there was last changed is asking a question about nothing.
    def path
      return unless File.exist?(@picture)

      draw if stale?

      file
    rescue Ffmpeg::Unreadable, Ffmpeg::NotInstalled
      # A cover.jpg that is not a JPEG is one of the things on a NAS, and an
      # ffmpeg that is not installed is one of the things on a laptop. Neither is
      # worth a broken picture: the page gets the file itself, exactly as it did
      # before any of this was here.
      nil
    end

    private

    # A better scan of a record, dropped onto the NAS over the old one, is a new
    # picture at a path that has not changed. The thumbnail beside it is then a
    # picture of something that is not there any more — so the clock decides,
    # rather than the name.
    def stale?
      !File.exist?(file) || File.mtime(file) < File.mtime(@picture)
    end

    # Written under another name and moved into place, because two requests for a
    # sleeve nobody has drawn yet arrive at the same moment, and a browser reading
    # a half-written JPEG shows half a JPEG. A rename is the one thing the
    # filesystem promises to do all at once.
    def draw
      FileUtils.mkdir_p(self.class.root)
      scratch = "#{file}.#{Process.pid}"

      File.binwrite(scratch, Ffmpeg.new.thumbnail(@picture, size: @size))
      File.rename(scratch, file)
    end

    # The same name the URL is keyed on, which is the path digested — so a picture
    # that moved is a different thumbnail, and one that did not is the same one.
    def file
      File.join(self.class.root, "#{MediaFile.signature(@picture)}-#{@size}.jpg")
    end
  end
end
