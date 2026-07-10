class Track < ApplicationRecord
  belongs_to :album
  has_many :playlist_entries, dependent: :destroy

  validates :title, presence: true
  validates :path, presence: true, uniqueness: true

  scope :ordered, -> { order(:disc_no, :track_no) }
end
