# A song heard, waiting to be told to Last.fm.
#
# It is a row rather than a request because the machine this runs on is a NAS in
# somebody's house, and the internet it needs is not the internet it has. Last.fm
# asks for exactly this — "hold scrobbles that need be retried in a local cache;
# this cache should survive client restarts" — and it will take them late.
class Scrobble < ApplicationRecord
  belongs_to :profile
  belongs_to :track

  # What Last.fm says it did with a scrobble, inside a response that was otherwise
  # a perfect success. Nought is "took it". Three is "that is too far in the past"
  # — and how far is too far is written down nowhere in Last.fm's documentation,
  # so the only honest way to find out is to send them and read what comes back.
  TAKEN = 0
  TOO_OLD = 3

  # Oldest first: Last.fm asks that they arrive in the order they were heard.
  scope :waiting, -> { where(sent_at: nil).order(:played_at, :id) }
  scope :taken, -> { where(ignored_as: TAKEN) }
  scope :too_old, -> { where(ignored_as: TOO_OLD) }
  scope :turned_away, -> { where.not(ignored_as: [ nil, TAKEN ]) }

  def sent? = sent_at.present?

  # Sent is not taken. Last.fm answers 200 OK and then says, in a code inside the
  # body, that it threw the scrobble away — because the artist is filtered, or
  # because the timestamp is too far in the past.
  def taken? = sent? && ignored_as == TAKEN

  def sent(ignored_as:)
    update!(sent_at: Time.current, ignored_as:)
  end

  # What Last.fm is told. The credit on the file rather than the sleeve, because a
  # guest or a duet is who actually sang it — and the sleeve is sent alongside, as
  # the album artist, which is exactly the distinction Last.fm draws too.
  def as_told_to_lastfm
    {
      artist: track.artist_name,
      track: track.title,
      album: track.album.title,
      albumArtist: track.album.artist.name,
      timestamp: played_at.to_i
    }.merge(track.duration.to_i.positive? ? { duration: track.duration.to_i } : {})
  end
end
