module Music
  # The first source that has a face wins.
  #
  # A source that cannot answer steps aside rather than ending the search: a NAS
  # that lost its uplink still has its disk.
  class FirstPortrait
    def initialize(*sources)
      @sources = sources
    end

    def portrait_of(artist)
      @sources.each do |source|
        found = ask(source, artist)
        return found if found
      end

      nil
    end

    private

    def ask(source, artist)
      source.portrait_of(artist)
    rescue StandardError => e
      Rails.logger.warn("#{source.class} has no portrait for #{artist.name}: #{e.message}")
      nil
    end
  end
end
