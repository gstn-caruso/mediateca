# One appearance of a track in a playlist. The position belongs to the
# appearance, not to the track, which is what lets a song show up twice.
class PlaylistEntry < ApplicationRecord
  belongs_to :playlist
  belongs_to :track

  scope :ordered, -> { order(:position) }
end
