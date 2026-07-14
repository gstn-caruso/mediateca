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
    #
    # The size arrives off a URL, and a URL can say anything: `?size[]=96` is an
    # Array, and an Array has no opinion about to_i. So it is read as a number or
    # it is not a size, and a thing that is not a size is one of the many sizes
    # this app does not draw.
    def self.of(picture, size:)
      wanted = Integer(size.to_s, exception: false)

      return unless picture.present? && SIZES.include?(wanted)

      new(picture.to_s, size: wanted).path
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
    rescue Ffmpeg::Unreadable, Ffmpeg::NotInstalled, SystemCallError
      # Three things, and one answer to all of them. A cover.jpg that is not a
      # JPEG is one of the things on a NAS. An ffmpeg that is not installed is one
      # of the things on a laptop. A disk with no room left on it, or mounted
      # read-only, is one of the things on a NAS as well — and before any of this
      # existed, a picture was served without writing a byte, so a full disk could
      # not make the library unreadable. It must not start now.
      #
      # None of them is worth a broken picture. The page gets the file itself,
      # exactly as it did before the app knew how to draw a small one.
      nil
    end

    private

    # A thumbnail wears the mtime of the picture it was drawn from, so the question
    # "is this still a picture of that?" is asked by comparing them, and answered
    # exactly.
    #
    # Not "was the picture touched more recently than the thumbnail". A sleeve does
    # not arrive on this NAS by being edited in place — it arrives by rsync -a, or
    # cp -p, which carry the file's own mtime along with the bytes, and that mtime
    # is usually older than the moment the app happened to draw the thumbnail. A
    # better scan of a record would have landed and never been looked at again.
    def stale?
      !File.exist?(file) || File.mtime(file) != File.mtime(@picture)
    end

    # Written under another name and moved into place, because two requests for a
    # sleeve nobody has drawn yet arrive at the same moment — and Puma answers
    # three at once in one process, so the other name has to be this THREAD's, not
    # this process's. Two threads sharing a scratch file write over each other and
    # the second one renames a file that is not there any more.
    #
    # A rename is the one thing the filesystem promises to do all at once: whoever
    # loses the race overwrites an identical picture with an identical picture, and
    # a browser never sees half a JPEG.
    def draw
      FileUtils.mkdir_p(self.class.root)
      scratch = "#{file}.#{Process.pid}.#{Thread.current.object_id}"

      File.binwrite(scratch, Ffmpeg.new.thumbnail(@picture, size: @size))
      File.utime(File.atime(@picture), File.mtime(@picture), scratch)
      File.rename(scratch, file)
    end

    # The same name the URL is keyed on, which is the path digested — so a picture
    # that moved is a different thumbnail, and one that did not is the same one.
    def file
      File.join(self.class.root, "#{MediaFile.signature(@picture)}-#{@size}.jpg")
    end
  end
end
