require "test_helper"

# PKCE: a secret is invented here, its hash is what Spotify is shown on the way
# out, and the secret itself is what proves on the way back that this is the same
# app that left. Nothing has to be kept — which is exactly right for something
# running on a NAS.
class ConnectingSpotifyTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @gaston = listening_as
    Spotify.api = @spotify = FakeSpotify.new
  end

  test "connecting sends the listener to Spotify, and says where to come back to" do
    get connect_spotify_path

    assert_response :redirect
    assert_match "accounts.spotify.com/authorize", response.location
    assert_match CGI.escape(callback_spotify_url), response.location
  end

  test "coming back with a code connects the account" do
    connect

    assert_equal "gaston", @gaston.reload.spotify_account.username
    assert_equal "rt", @gaston.spotify_account.refresh_token
  end

  # Spotify will not have `localhost` as a redirect, and says so by name: a
  # loopback address is allowed, and the word is not. Anybody developing this opens
  # http://localhost:3000 without thinking about it — and the callback built from
  # the host they typed is the one Spotify refuses, with "Not matching
  # configuration" and no hint as to which part it disliked.
  #
  # So the word is swapped for the address it means. It has to be swapped in both
  # legs of the journey: Spotify checks the redirect again when the code is
  # exchanged, and the two must match to the character.
  test "Spotify is never sent the word localhost, which it refuses" do
    listening_from "localhost:3000"

    get connect_spotify_path

    assert_match CGI.escape("http://127.0.0.1:3000/spotify/callback"), response.location
    assert_no_match(/localhost/, response.location)
  end

  test "a listener who came in by name is still sent back to it" do
    listening_from "nas.local"

    get connect_spotify_path

    assert_match CGI.escape("/spotify/callback"), response.location
    assert_match "nas.local", response.location
  end

  # The reason for the handshake. The way back is a GET, and a GET is a link — so
  # without it, anybody could send this listener a link carrying *their* code and
  # quietly connect the house to a stranger's Spotify.
  test "a code that came back from a journey nobody made is refused" do
    get callback_spotify_path, params: { code: "smuggled-in", state: "not-the-one-we-sent" }

    assert_predicate SpotifyAccount.all, :empty?
    assert_match(/Spotify/i, flash[:alert])
  end

  test "a code Spotify will not take connects nothing" do
    get connect_spotify_path
    get callback_spotify_path, params: { code: "no", state: handshake }

    assert_predicate SpotifyAccount.all, :empty?
    assert_match(/Spotify/i, flash[:alert])
  end

  test "disconnecting gives the account back" do
    connect

    delete spotify_path

    assert_predicate SpotifyAccount.all, :empty?
  end

  # Spotify hands back a new access token and, quite legally, no new refresh token.
  # A client that wrote the nothing over the old one would have disconnected itself
  # an hour later — silently, and a month before anybody noticed.
  test "a refresh that hands back no new refresh token does not throw away the old one" do
    connect
    @gaston.spotify_account.update!(expires_at: 1.minute.ago)

    assert_equal "a-fresh-one", @gaston.reload.spotify_account.token
    assert_equal "rt", @gaston.spotify_account.reload.refresh_token
  end

  test "asking Spotify for the hearts and lists sets something long-running going" do
    connect

    assert_enqueued_with job: ImportFromSpotifyJob do
      post import_spotify_path
    end
  end

  # No client id, no Spotify anywhere in the app.
  test "a Mediateca nobody gave a Spotify app to does not offer it" do
    Spotify.api = FakeSpotify.new(signed_in: false)

    get connect_spotify_path
    assert_redirected_to root_path

    get root_path
    assert_no_match "Connect Spotify", response.body
  end

  private

  # The cookie was signed for the host the test started on, so arriving at another
  # one is arriving as nobody.
  def listening_from(host)
    host! host
    post session_path, params: { profile_id: @gaston.id }
  end

  def handshake
    Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")
  end

  def connect
    get connect_spotify_path
    get callback_spotify_path, params: { code: "a-fresh-code", state: handshake }
  end
end
