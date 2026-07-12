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
end
