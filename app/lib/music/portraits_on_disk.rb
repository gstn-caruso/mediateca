module Music
  # A photograph left beside the records. Whoever put it there knows better than
  # any server, so nothing else is asked until this has answered.
  class PortraitsOnDisk
    NAMED = %w[artist folder].freeze
    IMAGES = "*.{jpg,jpeg,png,webp,JPG,JPEG,PNG}".freeze

    def portrait_of(artist)
      folder = folder_of(artist) or return
      file = named(folder) || only_image(folder) or return

      Portrait.new(bytes: File.binread(file), credit: nil)
    end

    private

    # The artist's folder is the one its records sit in.
    def folder_of(artist)
      album = artist.albums.first or return

      File.dirname(album.directory)
    end

    def named(folder)
      Dir.glob(File.join(folder, IMAGES)).find { |path| NAMED.include?(File.basename(path, ".*").downcase) }
    end

    # One picture loose in an artist's folder is a picture of that artist.
    def only_image(folder)
      Dir.glob(File.join(folder, IMAGES)).min
    end
  end
end
