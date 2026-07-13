# One track, once, by one listener. The history is the pile of these.
#
# Two things it now says that it did not.
#
# Where it was heard. Most of what anybody has ever listened to happened somewhere
# else, and Last.fm will hand the whole of it over — so a play carries its source,
# and only the ones heard *here* are ever told to anybody. Without that, connecting
# a Last.fm twice would hand Last.fm back its own history as though it were new.
#
# And what was heard. A play used to be a play of a record you own, because there
# was nothing else it could be. But a history of only the songs on your disk is a
# history of the wrong life — so a play is of a track you have, or of the gap where
# one you have not should be.
class Play < ApplicationRecord
  belongs_to :profile
  belongs_to :track, optional: true
  belongs_to :absence, optional: true

  HERE = "mediateca".freeze

  # Heard in this app, by this listener, on this NAS. The only listening this app
  # has any business telling anybody else about.
  scope :heard_here, -> { where(source: HERE) }

  # The listening that is of a record on the disk — what the counts, the turns and
  # the suggestions are all drawn from.
  scope :of_ours, -> { where.not(track_id: nil) }

  validate :one_or_the_other

  def ours? = track.present?

  def artist_name = ours? ? track.artist_name : absence.artist
  def title = ours? ? track.title : absence.title

  private

  def one_or_the_other
    return if track.present? ^ absence.present?

    errors.add(:base, "a play is of a song you have, or of the gap where one you have not should be")
  end
end
