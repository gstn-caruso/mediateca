# A heart, on its way to Last.fm.
#
# What is kept here is the *intent*, not the gesture: one row per song, holding
# the last thing the listener meant. Heart a song and unheart it before the queue
# drains and Last.fm is told once, correctly — it does not need to watch somebody
# change their mind.
class Love < ApplicationRecord
  belongs_to :profile
  belongs_to :track

  scope :waiting, -> { where(sent_at: nil).order(:id) }

  def sent? = sent_at.present?

  def sent
    update!(sent_at: Time.current)
  end

  # The credit on the file rather than the sleeve — a guest or a duet is who
  # actually sang it, and that is who Last.fm has the song under.
  def as_told_to_lastfm
    { artist: track.artist_name, track: track.title }
  end
end
