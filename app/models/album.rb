class Album < ApplicationRecord
  belongs_to :artist
  has_many :tracks, -> { ordered }, dependent: :destroy, inverse_of: :album

  validates :beets_id, presence: true, uniqueness: true
  validates :title, presence: true

  scope :ordered, -> { order(:year, :title) }
end
