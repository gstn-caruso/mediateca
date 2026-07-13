# The Spotify a listener has connected, so that what they kept there can be
# brought home.
#
# It is here for two things Last.fm cannot give: the songs you hearted on Spotify,
# and the lists you made. It is *not* here for your listening history — Spotify has
# no endpoint for that, at all, and never has. The only thing it will tell you is
# the last fifty songs you played. Your history lives on Last.fm, and that is where
# Mediateca goes for it.
#
# Both tokens are encrypted. The access token dies in an hour and is of little
# interest; the refresh token is a key to somebody's Spotify that does not expire
# on its own, and it is not a thing to leave lying in a database file that gets
# backed up.
class SpotifyAccount < ApplicationRecord
  belongs_to :profile

  encrypts :access_token
  encrypts :refresh_token

  validates :username, presence: true

  # Asked for a minute before it is actually due, because a token that expires
  # halfway through a page of a listener's library is a token that expired.
  A_MINUTE_EARLY = 1.minute

  def token
    refresh if expires_at <= A_MINUTE_EARLY.from_now

    access_token
  end

  def imported?
    imported_at.present?
  end

  def imported(hearts:, lists:, strangers:)
    update!(imported_at: Time.current, imported_hearts: hearts, imported_lists: lists, strangers:)
  end

  private

  # Spotify may or may not hand back a new refresh token. When it does not, the
  # one we have is still the one that works — and overwriting it with nothing is
  # how an integration silently disconnects itself a month later.
  def refresh
    given = Spotify.api.refreshed(refresh_token)

    update!(
      access_token: given.fetch(:access_token),
      refresh_token: given[:refresh_token].presence || refresh_token,
      expires_at: given.fetch(:expires_in).seconds.from_now
    )
  end
end
