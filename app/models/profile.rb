# Somebody who listens. There is no password: on a home LAN, picking your name
# off a grid is the whole of signing in.
class Profile < ApplicationRecord
  has_many :playlists, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :plays, dependent: :destroy

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
  def liked_tracks
    Track.joins(:likes).where(likes: { profile_id: id }).includes(album: :artist).order("likes.id DESC")
  end

  # For the row that leads to them, which says how many there are rather than
  # what kind of thing it is. Counted off the hearts already in hand, so a page
  # that renders hearts pays nothing for the number.
  def liked_songs_count
    hearts.count { |type, _id| type == "Track" }
  end

  def played(track)
    plays.create!(track:)
  end

  # Albums, not songs: four songs off one record are one record. Ordered by the
  # last play's id, which is monotonic where two timestamps could tie.
  def recently_played_albums(limit: 8)
    ids = plays.joins(:track)
               .group("tracks.album_id")
               .order(Arel.sql("MAX(plays.id) DESC"))
               .limit(limit)
               .pluck("tracks.album_id")

    found = Album.where(id: ids).includes(:artist).index_by(&:id)
    ids.filter_map { |id| found[id] }
  end

  private

  # A page full of songs asks about every one of them, and asking the database
  # each time is a query per row. A listener's hearts are a handful of rows, so
  # they come back once and the page reads them off memory. Current.profile is
  # this request's, so the memo cannot outlive the answer it holds.
  def hearts
    @hearts ||= likes.pluck(:likeable_type, :likeable_id).to_set
  end

  def forget_hearts
    @hearts = nil
  end
end
