module Music
  # What vanished and what appeared, paired up: one thing, moved.
  #
  # A scan tells things apart by where they sit — a folder, a path. So a file
  # renamed reads as one song gone and another arrived, when it is one song that
  # moved. Pairing them is what keeps a listener's playlists, hearts and history
  # attached to the song they were put on, instead of destroyed along with the
  # row that happened to carry the old name.
  #
  # Each side says its own name, because a row and the description of a file say
  # the same things in different words. Move only knows the rule: same name, and
  # only one of each answering to it.
  class Move
    # `gone` and `arrived` are each a list of [name, thing].
    def initialize(gone:, arrived:)
      @gone = gone
      @arrived = arrived
    end

    def each
      arrived = uniquely_named(@arrived)

      uniquely_named(@gone).each do |name, thing|
        moved = arrived[name]

        yield thing, moved if moved
      end
    end

    private

    # A name two things answer to names neither of them. Two songs that look
    # alike are no evidence that either one moved, and guessing wrong would hand
    # a playlist a song nobody put there — worse than losing the entry.
    def uniquely_named(named)
      named.group_by(&:first)
           .select { |_name, found| found.one? }
           .transform_values { |found| found.first.last }
    end
  end
end
