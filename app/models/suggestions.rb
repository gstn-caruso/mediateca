# What could come after the record ends.
#
# A home library has no recommender and needs none. The honest answer to "what
# now" is more of whoever you are already listening to — the artist is the whole
# of the taste on offer here — and only once they run out, anything else that is
# on the disk. Which of the two it found is worth saying out loud, so the rail
# can offer the second for what it is rather than dressing it up as the first.
class Suggestions
  # The rail is a rail, not a discography. Five is what fits under a song
  # without turning the panel into a page nobody reads.
  FEW = 5

  def initialize(track:, queued: [])
    @track = track
    @queued = Array(queued).map(&:to_i)
  end

  def tracks
    @tracks ||= from_the_artist.presence || from_the_library
  end

  def heading
    return "" if tracks.empty?

    from_the_artist.any? ? "More from #{artist.name}" : "From your library"
  end

  private

  def artist
    @track.album.artist
  end

  def from_the_artist
    @from_the_artist ||= unheard(Track.ordered.where(album: artist.albums)).first(FEW)
  end

  # The library in no particular order, because there is no particular order to
  # put it in: nothing here is more like Piazzolla than anything else, and a
  # fallback that always names the same song stops being a suggestion.
  def from_the_library
    unheard(Track.where.not(album: artist.albums).order(Arel.sql("RANDOM()"))).first(FEW)
  end

  # Neither the song playing nor anything already waiting behind it: a
  # suggestion is for what is *not* coming.
  def unheard(scope)
    scope.includes(album: :artist).where.not(id: @queued + [ @track.id ])
  end
end
