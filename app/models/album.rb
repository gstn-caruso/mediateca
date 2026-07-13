class Album < ApplicationRecord
  belongs_to :artist
  has_many :tracks, -> { ordered }, dependent: :destroy, inverse_of: :album
  has_many :likes, as: :likeable, dependent: :destroy

  validates :directory, presence: true, uniqueness: true
  validates :title, presence: true

  scope :ordered, -> { order(:year, :title) }

  # How records stand on a shelf: under whoever made them, oldest first. Ordered
  # by year alone — which is what one artist's records want — the whole library
  # comes out interleaved, every artist shuffled in among the others.
  scope :shelved, -> { joins(:artist).order("artists.name", :year, :title) }

  # A record is hidden by whoever made it. The library seen as records is the
  # same library seen as people, and an artist hidden in one turn of the rail
  # and standing there in the next would be hidden in neither.
  scope :visible_to, ->(profile) { where.not(artist_id: profile.hidden_artist_ids) }
end
