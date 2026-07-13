# Somebody who listens. There is no password: on a home LAN, picking your name
# off a grid is the whole of signing in.
class Profile < ApplicationRecord
  has_many :playlists, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :plays, dependent: :destroy
  has_many :spins, dependent: :destroy
  has_many :standings, dependent: :destroy

  # Nobody holds two Last.fm accounts at once, and a listener without one is the
  # ordinary case: the app is whole without Last.fm in it.
  has_one :scrobbler, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: true

  # Creation order, which the id already is. By name the grid would reshuffle
  # whenever somebody new arrives, and a profile that moves is a profile you
  # click by mistake.
  scope :ordered, -> { order(:id) }

  # Pressed twice — a double click, or the phone and the tablet at once — both
  # presses find nothing and both insert. The database has the last word on that
  # (it holds a unique index), and create_or_find_by lets it have it, rather than
  # raising in the listener's face over a heart they already gave.
  def like(thing)
    likes.create_or_find_by!(likeable: thing).tap { forget_hearts }
  end

  def unlike(thing)
    likes.where(likeable: thing).destroy_all
    forget_hearts
  end

  def likes?(thing)
    hearts.include?([ thing.class.name, thing.id ])
  end

  # Newest first: the song you just hearted is the one you came looking for.
  # Minus whoever you have hidden — the heart is still on the song, and comes
  # back with them.
  def liked_tracks
    Track.joins(:likes).where(likes: { profile_id: id })
         .visible_to(self)
         .includes(album: :artist).order("likes.id DESC")
  end

  # For the row that leads to them, which says how many there are rather than
  # what kind of thing it is. It has to count the same songs the page lists, or
  # the rail promises a number the list does not keep — so it counts them, and
  # a hearted song by a hidden artist is not one of them.
  def liked_songs_count
    liked_tracks.count
  end

  # An artist you would rather not be shown. It is not a deletion: the records
  # are still on the disk and still in the catalog, and searching the name by
  # hand still finds them. It only means the library stops putting them in front
  # of you, and nothing ever offers them unasked.
  def hide(artist)
    stand(artist, as: :hidden)
  end

  def unhide(artist)
    drop(artist, if_it_is: :hidden)
  end

  # The opposite, and the reason the two share a row: an artist worth hearing
  # more of, whatever else is playing.
  def highlight(artist)
    stand(artist, as: :highlighted)
  end

  def unhighlight(artist)
    drop(artist, if_it_is: :highlighted)
  end

  def hides?(artist)
    hidden_artist_ids.include?(artist.id)
  end

  def highlights?(artist)
    highlighted_artist_ids.include?(artist.id)
  end

  def hidden_artist_ids
    @hidden_artist_ids ||= artist_ids_standing("hidden")
  end

  def highlighted_artist_ids
    @highlighted_artist_ids ||= artist_ids_standing("highlighted")
  end

  # Written down once the listener has heard enough of the song to have listened
  # to it — which is a while after the music started. The player is the only one
  # who was there when it did, so it is the player who says when.
  #
  # A song is also the last song of some record, and hearing it may be the moment
  # that record came full circle.
  def played(track, at: Time.current)
    plays.create!(track:, played_at: at).tap do |play|
      came_full_circle(play)
      forget_tally
    end
  end

  # Connecting a Last.fm — again, or to a different account — replaces whatever
  # was there. Coming back from Last.fm twice is a double click, not two accounts.
  def scrobbles_to(username:, session_key:)
    (scrobbler || build_scrobbler).tap { it.update!(username:, session_key:) }
  end

  def stops_scrobbling
    scrobbler&.destroy
    reload_scrobbler
  end

  def scrobbles?
    scrobbler.present?
  end

  # How many times this listener has heard the whole record.
  def spins_of(album)
    spins.where(album:).count
  end

  # How many times this listener has heard this song.
  def times_played(track)
    tally.fetch(track.id, 0)
  end

  # Reloading is going back to the database to ask again, so what was remembered
  # from the last time has to go with it. Without this a reloaded profile answers
  # about hearts and standings out of a memory the reload was meant to throw
  # away — which never bites a request, since Current.profile lives and dies
  # inside one, and bites every test that reloads.
  def reload(...)
    forget_hearts
    forget_standings
    forget_tally
    super
  end

  # Albums, not songs: four songs off one record are one record. Ordered by the
  # last play's id, which is monotonic where two timestamps could tie.
  #
  # A hidden artist is dropped in the *query*, not after it: dropped afterwards,
  # a shelf of eight would come back with seven and no eighth to take the place.
  def recently_played_albums(limit: 8)
    ids = plays.joins(track: :album)
               .where.not(albums: { artist_id: hidden_artist_ids })
               .group("tracks.album_id")
               .order(Arel.sql("MAX(plays.id) DESC"))
               .limit(limit)
               .pluck("tracks.album_id")

    found = Album.where(id: ids).includes(:artist).index_by(&:id)
    ids.filter_map { |id| found[id] }
  end

  private

  # A song heard may be the one that was still missing off some record. Every
  # song on it, heard since the run began, means the record came full circle.
  def came_full_circle(play)
    album = play.track.album

    spins.create!(album:, play:) if heard_since_the_run_began(album) == album.tracks.ids.to_set
  end

  # A turn of the record is uninterrupted, so the run begins after the last thing
  # that broke it: something else put on, or the turn this record already made —
  # whose songs are finished business, and whose successor starts from there.
  def heard_since_the_run_began(album)
    began = [ last_put_on_something_else(album), last_turn_of(album) ].compact.max || 0

    plays.joins(:track)
         .where(tracks: { album_id: album.id }, plays: { id: began.succ.. })
         .distinct.pluck(:track_id).to_set
  end

  def last_put_on_something_else(album)
    plays.joins(:track).where.not(tracks: { album_id: album.id }).maximum(:id)
  end

  def last_turn_of(album)
    spins.where(album:).maximum(:play_id)
  end

  # A page full of songs asks about every one of them, and asking the database
  # each time is a query per row. A listener's hearts are a handful of rows, so
  # they come back once and the page reads them off memory. Current.profile is
  # this request's, so the memo cannot outlive the answer it holds.
  def hearts
    @hearts ||= likes.pluck(:likeable_type, :likeable_id).to_set
  end

  # The same bargain, for how many times each song was heard: a record's page
  # asks about every song on it, and one query answers for all of them.
  def tally
    @tally ||= plays.group(:track_id).count
  end

  def forget_tally
    @tally = nil
  end

  def forget_hearts
    @hearts = nil
  end

  # Pressed twice, both presses find nothing and both insert; and pressing hide
  # on somebody already highlighted has to *replace* the standing, not add a
  # second one. create_or_find_by lets the unique index settle the first, and
  # the update settles the second.
  def stand(artist, as:)
    standings.create_or_find_by!(artist:) { it.standing = as }.tap do |standing|
      standing.update!(standing: as)
      forget_standings
    end
  end

  # Undoing one standing is not undoing the other: unhiding an artist you have
  # since highlighted would quietly take the highlight away.
  def drop(artist, if_it_is:)
    standings.where(artist:, standing: if_it_is).destroy_all
    forget_standings
  end

  # The same bargain the hearts strike: a page full of artists asks about every
  # one of them, and a listener's standings are a handful of rows. They come
  # back once, and the page reads them off memory.
  def artist_ids_standing(standing)
    standings_taken.filter_map { |artist_id, taken| artist_id if taken == standing }
  end

  def standings_taken
    @standings_taken ||= standings.pluck(:artist_id, :standing)
  end

  def forget_standings
    @standings_taken = @hidden_artist_ids = @highlighted_artist_ids = nil
  end
end
