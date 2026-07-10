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

  def like(thing)
    likes.find_or_create_by!(likeable: thing)
  end

  def unlike(thing)
    likes.where(likeable: thing).destroy_all
  end

  def likes?(thing)
    likes.exists?(likeable: thing)
  end

  # Newest first: the song you just hearted is the one you came looking for.
  def liked_tracks
    Track.joins("INNER JOIN likes ON likes.likeable_id = tracks.id AND likes.likeable_type = 'Track'")
         .where(likes: { profile_id: id })
         .includes(album: :artist)
         .order("likes.id DESC")
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
end
