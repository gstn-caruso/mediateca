module Music
  # The words of a song, and — when somebody timed them — when each one is sung.
  #
  # They come off the disk as an .lrc sitting beside the file, which is where
  # every music player has looked for them since Winamp. Two kinds live in that
  # one format: a timed file, whose every line is stamped with the moment it
  # lands, and a plain one, which is only the words. The panel can follow the
  # first and can only show the second, so a Lyrics is asked which it is.
  class Lyrics
    # A line of the song: `at` is when it is sung, or nil in a file nobody timed.
    Line = Data.define(:at, :text)

    # [mm:ss.cc], and the minutes go on past sixty — a 70-minute live take is
    # still one song. Hundredths are what LRCLIB writes; thousandths and a colon
    # instead of a dot are what other writers write, and all of them are a time.
    TIMESTAMP = /\[(\d+):(\d{1,2}(?:[.:]\d{1,3})?)\]/

    # What an .lrc says about itself — [ar:…], [ti:…], [length:…]. It is about
    # the file, not the song, and sung out loud it would be nonsense.
    HEADER = /\A\[[^\[\]]+\]\z/

    attr_reader :lines

    def initialize(lines)
      @lines = lines
    end

    # A song nobody found the words to still answers; it just has nothing to say.
    def self.none
      new([])
    end

    # The .lrc that lives beside the song, if anybody wrote one. The path comes
    # from the catalog and the catalog was filled from the disk, but a path is
    # only trusted as far as MediaFile trusts it — the sidecar sits in the same
    # read-only root as the music, and is held to it.
    def self.beside(path)
      file = MediaFile.new(sidecar(path))

      file.exist? ? parse(::File.read(file.path)) : none
    end

    def self.sidecar(path)
      path.to_s.sub(/\.[^.\/]+\z/, ".lrc")
    end

    def self.parse(text)
      timed = []
      plain = []

      text.to_s.each_line do |raw|
        line = raw.chomp
        times = line.scan(TIMESTAMP)
        words = line.gsub(TIMESTAMP, "").strip

        if times.any?
          # A chorus is written once and sung twice: one line, both its times.
          times.each { |minutes, rest| timed << Line.new(at: seconds(minutes, rest), text: words) }
        elsif !line.match?(HEADER) && words.present?
          plain << Line.new(at: nil, text: words)
        end
      end

      # One file is one kind. A timed file may carry a stray untimed line — a
      # credit, a stray blank — and it is not a lyric that lands at no time.
      new(timed.any? ? timed.sort_by(&:at) : plain)
    end

    def self.seconds(minutes, rest)
      (minutes.to_i * 60) + rest.tr(":", ".").to_f
    end

    private_class_method :sidecar, :seconds

    # Whether the panel can follow the song or only show it.
    def synced?
      lines.any? { it.at }
    end

    def empty?
      lines.empty?
    end

    def as_json(*)
      { synced: synced?, lines: lines.map { { at: it.at, text: it.text } } }
    end
  end
end
