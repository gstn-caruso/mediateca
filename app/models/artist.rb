class Artist < ApplicationRecord
  include Coloured

  has_many :albums, dependent: :destroy
  has_many :standings, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  # An artist's colour is the one they were photographed in — not the one on a
  # sleeve they made. A record is not a face, and it is not a face's colour either.
  def picture
    portrait_path
  end

  # What putting an artist on plays: their shelf, end to end. Oldest record first
  # and each in its running order — which is the order the records stand in, and
  # the only order a body of work has ever been listened to in.
  def songs
    albums.ordered.includes(:tracks).flat_map(&:tracks)
  end

  # Everyone a listener has not hidden — which is nearly everyone, since hiding
  # somebody is a thing you have to go and do. This is what the library shows of
  # its own accord; it is not what a search answers, because somebody typing a
  # name is asking, not being offered.
  scope :visible_to, ->(profile) { where.not(id: profile.hidden_artist_ids) }
end
