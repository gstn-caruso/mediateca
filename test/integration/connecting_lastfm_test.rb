require "test_helper"

# Connecting a Last.fm is a journey and back: you leave to say yes on Last.fm's
# own page, and return holding a token, which is spent here for a session key.
# Mediateca never sees a Last.fm password, and Last.fm never sees this house.
class ConnectingLastfmTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    Lastfm.api = @lastfm = FakeLastfm.new
  end

  test "connecting sends the listener to Last.fm, and says where to come back to" do
    get connect_scrobbler_path

    assert_response :redirect
    assert_match "last.fm/api/auth", response.location
    assert_match CGI.escape(callback_scrobbler_url), response.location
  end

  test "coming back with a token connects the account" do
    connect_with_a_token

    assert_equal "gaston", @gaston.reload.scrobbler.username
    assert_equal "s3ss10nk3y", @gaston.scrobbler.session_key
  end

  test "connecting again replaces the account rather than keeping two" do
    connect_with_a_token
    Lastfm.api = FakeLastfm.new(username: "someone-else", session_key: "another")

    connect_with_a_token

    assert_equal 1, Scrobbler.count
    assert_equal "someone-else", @gaston.reload.scrobbler.username
  end

  test "disconnecting gives the account back" do
    connect_with_a_token

    delete scrobbler_path

    assert_predicate Scrobbler.all, :empty?
    assert_not @gaston.reload.scrobbles?
  end

  # A token Last.fm will not take is not a crisis: it is an hour-old token, or a
  # spent one. Nothing is connected and the listener is told.
  test "a token Last.fm refuses connects nothing" do
    get callback_scrobbler_path, params: { token: "no", handshake: handshake }

    assert_predicate Scrobbler.all, :empty?
    assert_redirected_to root_path
    assert_match(/Last.fm/i, flash[:alert])
  end

  test "a Last.fm nobody can reach connects nothing" do
    Lastfm.api = FakeLastfm::Unreachable.new

    get callback_scrobbler_path, params: { token: "whatever", handshake: handshake }

    assert_predicate Scrobbler.all, :empty?
    assert_match(/Last.fm/i, flash[:alert])
  end

  # The reason for the handshake. The way back from Last.fm is a GET, and a GET is
  # a link — so anybody could send this listener a link carrying *their* token,
  # and quietly have the house scrobble into a stranger's account. The token is
  # only taken if we are the ones who sent them to Last.fm.
  test "a token that came back from a journey nobody made is refused" do
    get callback_scrobbler_path, params: { token: "smuggled-in", handshake: "not-the-one-we-sent" }

    assert_predicate Scrobbler.all, :empty?
    assert_empty @lastfm.spent
    assert_match(/Last.fm/i, flash[:alert])
  end

  test "a way back with no handshake at all is refused" do
    get callback_scrobbler_path, params: { token: "smuggled-in" }

    assert_predicate Scrobbler.all, :empty?
    assert_empty @lastfm.spent
  end

  # A handshake is good for the one journey it was made for.
  test "the same handshake cannot be used twice" do
    said = handshake
    get callback_scrobbler_path, params: { token: "first", handshake: said }

    get callback_scrobbler_path, params: { token: "again", handshake: said }

    assert_equal [ "first" ], @lastfm.spent
  end

  # Without an API account there is no Last.fm in this app at all: the menu says
  # nothing about it, and the way in is shut.
  test "a Mediateca nobody gave Last.fm credentials to does not offer it" do
    Lastfm.api = FakeLastfm.new(configured: false)

    get connect_scrobbler_path

    assert_redirected_to root_path
    assert_predicate Scrobbler.all, :empty?

    get root_path
    assert_no_match "Last.fm", response.body
  end

  # The way in is the menu under the avatar — the one place in the app that is
  # about the listener rather than the music.
  test "the profile menu offers Last.fm before you have ever connected it" do
    get root_path

    assert_select "#topbar a", text: "Connect Last.fm"
  end

  # Without an API account there is no Last.fm in this app at all — not even a
  # word about it in the one menu that would otherwise offer it.
  test "the profile menu says nothing about Last.fm without an API account" do
    Lastfm.api = FakeLastfm.new(configured: false)

    get root_path

    assert_select "#topbar", text: /Last\.fm/, count: 0
  end

  private

  # What the listener's browser is holding when Last.fm sends it back. Leaving for
  # Last.fm is what puts it there, so the journey starts with the leaving.
  def handshake
    get connect_scrobbler_path

    Rack::Utils.parse_query(URI.parse(response.location).query)
                .fetch("cb").then { Rack::Utils.parse_query(URI.parse(it).query).fetch("handshake") }
  end

  def connect_with_a_token
    get callback_scrobbler_path, params: { token: "a-fresh-token", handshake: handshake }
  end
end
