require "fileutils"

module Music
  # A photograph for every artist that has none. Asked for once: the scope is
  # the artists with no portrait, so a second run asks nobody.
  #
  # The bytes land under storage/, the only writable volume — the music is
  # mounted read-only, and a picture is not part of the record anyway. The file
  # is named after its own contents, so two artists photographed alike share one
  # file, and a portrait that changes cannot keep an old URL.
  class Portraits
    PNG = "\x89PNG".b.freeze

    def initialize(source:, root: Rails.configuration.x.portraits_root)
      @source = source
      @root = root.to_s
    end

    def collect(artists = Artist.where(portrait_path: nil))
      artists.find_each { |artist| collect_for(artist) }
    end

    private

    # blank? reads the bytes as text, and a PNG is not text.
    def collect_for(artist)
      portrait = @source.portrait_of(artist)
      return if portrait.nil? || portrait.bytes.nil? || portrait.bytes.empty?

      artist.update!(portrait_path: write(portrait.bytes), portrait_credit: portrait.credit)
    end

    def write(bytes)
      FileUtils.mkdir_p(@root)
      path = File.join(@root, "#{Digest::SHA256.hexdigest(bytes).first(16)}#{extension(bytes)}")
      File.binwrite(path, bytes) unless File.exist?(path)

      path
    end

    # The bytes say what they are. A file name would only repeat what a stranger
    # called them, and the browser is told the type from the name.
    def extension(bytes)
      bytes.b.start_with?(PNG) ? ".png" : ".jpg"
    end
  end
end
