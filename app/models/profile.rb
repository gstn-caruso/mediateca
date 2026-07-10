# Somebody who listens. There is no password: on a home LAN, picking your name
# off a grid is the whole of signing in.
class Profile < ApplicationRecord
  has_many :playlists, dependent: :destroy

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: true

  # Creation order, which the id already is. By name the grid would reshuffle
  # whenever somebody new arrives, and a profile that moves is a profile you
  # click by mistake.
  scope :ordered, -> { order(:id) }
end
