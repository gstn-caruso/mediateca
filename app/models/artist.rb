class Artist < ApplicationRecord
  include Coloured

  has_many :albums, dependent: :destroy
  has_many :standings, dependent: :destroy

  # Who Last.fm says this one is like, among the artists this house owns records
  # by. The one thing a home library cannot work out for itself: the disk knows
  # what you own and the history knows what you play, and neither of them knows
  # that Hermética is what comes after Almafuerte.
  has_many :kinships, dependent: :destroy
  has_many :kin, through: :kinships

  # And the other way round: an artist removed by a rescan must not leave a
  # kinship pointing at nobody.
  has_many :kinships_to_them, class_name: "Kinship", foreign_key: :kin_id, dependent: :destroy, inverse_of: :kin

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
