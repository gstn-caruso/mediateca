class Artist < ApplicationRecord
  has_many :albums, dependent: :destroy
  has_many :standings, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  scope :ordered, -> { order(:name) }

  # Everyone a listener has not hidden — which is nearly everyone, since hiding
  # somebody is a thing you have to go and do. This is what the library shows of
  # its own accord; it is not what a search answers, because somebody typing a
  # name is asking, not being offered.
  scope :visible_to, ->(profile) { where.not(id: profile.hidden_artist_ids) }
end
