# Spotify, without Spotify.
#
# It holds what a listener kept there, and hands it over the way the real Api does.
# It knows nothing about a history, because Spotify has no history to give.
class FakeSpotify
  attr_reader :asked_with

  def initialize(signed_in: true, username: "gaston")
    @signed_in = signed_in
    @username = username
    @songs = []
    @records = []
    @lists = {}
    @asked_with = []
  end

  def keeping(songs: [], records: [], lists: {})
    @songs = songs
    @records = records
    @lists = lists
    self
  end

  def signed_in? = @signed_in
  def configured? = @signed_in

  def authorize_url(returning_to:, verifier:, state:)
    "https://accounts.spotify.com/authorize?#{URI.encode_www_form(redirect_uri: returning_to, state:)}"
  end

  def tokens_for(code:, verifier:, returning_to:)
    raise Spotify::Api::Refused, "Spotify: invalid_grant" if code == "no"

    { access_token: "at", refresh_token: "rt", expires_in: 3600 }
  end

  # Spotify may hand back a new refresh token, and may not. This one does not,
  # which is the case that breaks a careless client.
  def refreshed(_refresh_token)
    { access_token: "a-fresh-one", refresh_token: nil, expires_in: 3600 }
  end

  def me(token:) = { username: @username }

  def saved_tracks(token:)
    @asked_with << token
    @songs
  end

  def saved_albums(token:) = @records

  def playlists(token:)
    @lists.keys.map { { id: it, name: it } }
  end

  def playlist_songs(id, token:) = @lists.fetch(id, [])
end
