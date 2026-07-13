# The Last.fm a listener has connected: who they are there, the key that lets this
# app act as them, and the thing that does the acting.
#
# The key is encrypted, and it is worth saying why in a house with no passwords.
# The bargain in SECURITY.md is about a music library on a home LAN — anybody who
# can reach it can be anybody. It was never a bargain about somebody's Last.fm
# account, and a session key Last.fm never expires is not a thing to leave lying
# in a database file that gets backed up.
class Scrobbler < ApplicationRecord
  belongs_to :profile

  encrypts :session_key

  validates :username, presence: true
  validates :session_key, presence: true

  # Last.fm's rule, and it is theirs to make: "The track must be longer than 30
  # seconds." A jingle still counts as a play here — you heard it — but it is not
  # a thing Last.fm will take, so it is not a thing we queue.
  BRIEFEST = 30

  # All Last.fm will take in one breath.
  BREATH = 50

  # Last.fm's own page for this listener. Its terms ask that a profile we show
  # links back to the profile it came from.
  def url
    "https://www.last.fm/user/#{CGI.escape(username)}"
  end

  # Queued, not sent: the sending is somebody else's afternoon, and a listener
  # pressing play should never wait on a website.
  def scrobble(play)
    return unless play.track.duration.to_f > BRIEFEST

    profile.scrobbles.create_or_find_by!(track: play.track, played_at: play.played_at)
    ScrobbleJob.perform_later(profile)
  end

  # Told as the song starts rather than when it counts, because it is what puts
  # the song on a listener's Last.fm page *while it is playing*. Last.fm asks that
  # a failed one never be retried: by the time a retry landed it would be a lie.
  def now_playing(track)
    Lastfm.api.now_playing(what(track), as: session_key)
  end

  # Everything waiting, oldest first and fifty at a time, until there is nothing
  # left. A batch that fails raises, and the job that called this tries again —
  # which is the whole reason the songs are rows and not requests.
  def send_what_is_waiting
    while (breath = profile.scrobbles.waiting.limit(BREATH).to_a).any?
      told = Lastfm.api.scrobble(breath.map(&:as_told_to_lastfm), as: session_key)

      breath.zip(told).each { |scrobble, ignored_as| scrobble.sent(ignored_as:) }
    end
  rescue Lastfm::Api::Revoked
    # They took the privilege back on Last.fm's own settings page. There is
    # nothing to retry and nothing to keep — but the songs stay queued, for
    # whenever they connect again.
    destroy
  end

  private

  def what(track)
    {
      artist: track.artist_name,
      track: track.title,
      album: track.album.title,
      albumArtist: track.album.artist.name
    }
  end
end
