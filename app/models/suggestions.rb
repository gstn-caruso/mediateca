# What could come after the record ends.
#
# A home library has no recommender and needs none. The honest answer to "what
# now" is more of whoever you are already listening to — the artist is the whole
# of the taste on offer here — and only once they run out, anything else that is
# on the disk. Which of the two it found is worth saying out loud, so the rail
# can offer the second for what it is rather than dressing it up as the first.
#
# What a listener has said about an artist bends both halves of that. Somebody
# hidden is never offered — not from the library, and not even while they are
# playing, since putting a record on by hand is not asking to be handed more of
# it. Somebody highlighted is offered *more*: a couple of the rail's slots are
# theirs whatever else is on, and when the draw comes they are heavier in it.
class Suggestions
  # The rail is a rail, not a discography. Five is what fits under a song
  # without turning the panel into a page nobody reads.
  FEW = 5

  # How much of the rail a highlighted artist may take when the artist playing
  # still has songs to give. Two of five: enough to be a real offer, few enough
  # that the record you are on is still what the rail is about.
  A_COUPLE = 2

  # How much heavier a highlighted artist is when the library is drawn from:
  # their songs go into the hat three times over. Weighted by *repetition* and
  # not by arithmetic, because SQLite's RANDOM() is a signed 64-bit integer, and
  # multiplying one of those is not a weight — it is a bug that looks like one.
  THREEFOLD = 3

  def initialize(track:, profile:, queued: [])
    @track = track
    @profile = profile
    @queued = Array(queued).map(&:to_i)
  end

  def tracks
    @tracks ||= from_the_artist.any? ? with_the_highlighted(from_the_artist) : from_elsewhere
  end

  def heading
    return "" if tracks.empty?
    return "More from #{artist.name}" if from_the_artist.any?

    from_the_kin.any? ? "Like #{artist.name}" : "From your library"
  end

  private

  attr_reader :profile

  def artist
    @track.album.artist
  end

  # The rail leads with the record you are on, and gives a couple of its slots
  # away to whoever you have highlighted. The rows it gives away name their own
  # artist, so the heading over them still reads true: this *is* more from the
  # artist, with a couple of songs you asked to be handed more often.
  def with_the_highlighted(mine)
    theirs = from_the_highlighted
    mine.first(FEW - theirs.size) + theirs
  end

  def from_the_artist
    @from_the_artist ||= unheard(Track.ordered.where(album: artist.albums)).first(FEW)
  end

  # Their featured songs — which is not a list anybody keeps here, and does not
  # need to be. The songs of theirs you go back to are the ones you have played,
  # and the database has been writing that down all along. A song nobody has
  # played yet counts nothing and sorts last, which is also the answer for an
  # artist you highlighted without ever having heard: any of them, then.
  #
  # Never the artist already playing: the rail is theirs already, and a slot
  # spent on them would only be one of their songs pushing out another.
  def from_the_highlighted
    @from_the_highlighted ||= begin
      ids = profile.highlighted_artist_ids - [ artist.id ]

      return [] if ids.empty?

      unheard(Track.where(album: Album.where(artist_id: ids)))
        .joins(played_by_this_listener)
        .group(:id)
        .order(Arel.sql("COUNT(plays.id) DESC"))
        .first(A_COUPLE)
    end
  end

  # A song of theirs is counted only if *you* played it. An ordinary join would
  # drop every song nobody has played, and the artist you highlighted but never
  # heard would have nothing to offer at all; a plain left join would count the
  # whole house's listening as though it were yours.
  def played_by_this_listener
    Track.sanitize_sql_array(
      [ "LEFT JOIN plays ON plays.track_id = tracks.id AND plays.profile_id = ?", profile.id ]
    )
  end

  # Once the record you are on runs out, the best answer in the house is whoever
  # is like them — and the random draw is what is left when nobody knows.
  def from_elsewhere
    from_the_kin.any? ? with_the_highlighted(from_the_kin) : from_the_library
  end

  # Who Last.fm says the artist playing is like, kept down to the ones whose
  # records are actually on this disk: a band the rail cannot put on is not an
  # offer. This is the one thing a home library cannot work out for itself — the
  # disk knows what you own and the history knows what you play, and neither of
  # them knows that Hermética is what comes after Almafuerte.
  #
  # It is the same hat and the same draw as the library fallback, weighted by how
  # alike Last.fm says they are, so a close cousin comes up often and a distant one
  # hardly ever.
  def from_the_kin
    @from_the_kin ||= begin
      closeness = artist.kinships.pluck(:kin_id, :match).to_h

      closeness.empty? ? [] : drawn_from(hat_of(closeness))
    end
  end

  def hat_of(closeness)
    unheard(Track.where(album: Album.where(artist_id: closeness.keys)))
      .joins(:album)
      .pluck(:id, "albums.artist_id")
      .flat_map { |id, artist_id| [ id ] * as_close_as(closeness[artist_id]) }
  end

  # Last.fm scores a kinship between nought and one, and a hat is counted in whole
  # songs — so the score becomes how many times the song goes in. Every kin goes in
  # at least once: Last.fm calling them kin at all is worth a chance.
  def as_close_as(match)
    [ (match.to_f * 10).round, 1 ].max
  end

  # The library in no particular order, because there is no particular order to
  # put it in: nothing here is more like Piazzolla than anything else — and when
  # nobody has told us otherwise, that is still true. A fallback that always names
  # the same song stops being a suggestion.
  #
  # Drawn in Ruby rather than by RANDOM(), because the draw is weighted and a
  # weighted draw is the one thing SQL makes hard to say plainly. A thousand ids
  # is a small handful of numbers; the songs themselves are fetched only once the
  # five are known.
  def from_the_library
    drawn_from(hat)
  end

  # Every song that could come up, with a highlighted artist's in it threefold.
  def hat
    unheard(Track.where.not(album: artist.albums))
      .joins(:album)
      .pluck(:id, "albums.artist_id")
      .flat_map { |id, artist_id| [ id ] * weight_of(artist_id) }
  end

  # Shuffle, keep the first few, and fetch the songs only once it is known which
  # few they are.
  def drawn_from(hat)
    drawn = draw(hat)

    Track.where(id: drawn).includes(album: :artist).sort_by { drawn.index(it.id) }
  end

  def weight_of(artist_id)
    profile.highlighted_artist_ids.include?(artist_id) ? THREEFOLD : 1
  end

  # Shuffle the hat and keep each song where it first turns up. A song written
  # in three times has three chances to turn up early, which is the whole of what
  # "heavier" means — and it still comes back once, because the rail offers a
  # song, not a song three times.
  def draw(hat)
    hat.shuffle.uniq.first(FEW)
  end

  # Neither the song playing nor anything already waiting behind it — a
  # suggestion is for what is *not* coming — and nobody this listener has hidden,
  # which is what hiding somebody means.
  def unheard(scope)
    scope.visible_to(profile).where.not(id: @queued + [ @track.id ])
  end
end
