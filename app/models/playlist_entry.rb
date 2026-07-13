# One line in a playlist. The position belongs to the line, not to what is on it,
# which is what lets a song show up twice.
#
# What is on it is a song you have — or, for a list brought home from Spotify, the
# name of one you have not. A list you kept somewhere else is the list you kept:
# quietly dropping the songs this house happens not to own would hand you back a
# shorter list and never say why. So the gaps come home too, drawn grey, playing
# nothing, and saying plainly what is missing.
class PlaylistEntry < ApplicationRecord
  belongs_to :playlist
  belongs_to :track, optional: true
  belongs_to :absence, optional: true

  scope :ordered, -> { order(:position) }

  # Everything that can actually be put on: what the play button queues, and what
  # a length is added up from.
  scope :playable, -> { where.not(track_id: nil) }

  validate :one_or_the_other

  def playable?
    track.present?
  end

  # Whoever it is by and whatever it is called, however little of it we have.
  def artist_name = playable? ? track.artist_name : absence.artist
  def title = playable? ? track.title : absence.title

  private

  def one_or_the_other
    return if track.present? ^ absence.present?

    errors.add(:base, "a line in a list is a song you have, or the name of one you have not")
  end
end
