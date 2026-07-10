class Track < ApplicationRecord
  belongs_to :album

  validates :beets_id, presence: true, uniqueness: true
  validates :title, presence: true
  validates :path, presence: true, uniqueness: true

  scope :ordered, -> { order(:disc_no, :track_no) }
end
