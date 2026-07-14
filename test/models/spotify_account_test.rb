require "test_helper"

class SpotifyAccountTest < ActiveSupport::TestCase
  # Spotify hands back a new access token and, quite legally, no new refresh token.
  # A client that wrote the nothing over the old one would have disconnected itself
  # an hour later — silently, and a month before anybody noticed.
  test "a refresh that hands back no new refresh token does not throw away the old one" do
    Spotify.api = FakeSpotify.new
    gaston = Profile.create!(name: "Gastón")
    gaston.connects_spotify(username: "gaston", access_token: "at", refresh_token: "rt", expires_in: 3600)
    gaston.spotify_account.update!(expires_at: 1.minute.ago)

    assert_equal "a-fresh-one", gaston.reload.spotify_account.token
    assert_equal "rt", gaston.spotify_account.reload.refresh_token
  end
end
