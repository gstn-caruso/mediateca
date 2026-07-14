require "test_helper"

class SuggestingWhatToPlayNextTest < ActionDispatch::IntegrationTest
  setup do
    @piazzolla = Artist.create!(name: "Astor Piazzolla")
    @regina = Album.create!(directory: "/music/regina", title: "En el Regina", artist: @piazzolla)
    @playing = track("La evasion", 1)
    @libertango = track("Libertango", 2)
  end

  # The rail queues what it is given, so what it is given has to be a track the
  # player can queue: where to stream it, and everything the row will show.
  test "a suggestion arrives ready to be queued" do
    listening_as

    get track_suggestions_path(@playing)

    assert_response :success
    assert_equal "More from Astor Piazzolla", body["heading"]

    suggestion = body["tracks"].sole
    assert_equal @libertango.id, suggestion["trackId"]
    assert_equal "Libertango", suggestion["title"]
    assert_equal "Astor Piazzolla", suggestion["subtitle"]
    assert_equal "En el Regina", suggestion["albumTitle"]
    assert_equal album_path(@regina), suggestion["album"]
    # Signed the way every other media URL in the app is, so a cached response
    # can never be revalidated into another song's audio.
    assert_equal track_stream_path(@libertango, v: MediaFile.signature(@libertango.path)), suggestion["src"]
    assert_equal album_cover_path(@regina, v: MediaFile.signature(@regina.cover_path), size: 96), suggestion["cover"]
  end

  test "what the queue already holds is not offered again" do
    listening_as

    get track_suggestions_path(@playing), params: { queued: "#{@playing.id},#{@libertango.id}" }

    assert_response :success
    assert_empty body["tracks"]
    assert_empty body["heading"]
  end

  # Suggestions read the library, and the library is only for whoever is
  # listening.
  test "nobody listening is offered nothing" do
    get track_suggestions_path(@playing)

    assert_redirected_to profiles_path
  end

  # The rail is answered for *whoever is asking*. A hiding is one listener's, and
  # so is the rail that honours it — the house does not agree about music, and
  # nobody has to.
  test "the rail is answered for the listener holding the cookie" do
    gaston = listening_as
    gaston.hide(@piazzolla)

    get track_suggestions_path(@playing)

    assert_response :success
    assert_empty body["tracks"]

    listening_as("Ana")
    get track_suggestions_path(@playing)

    assert_equal [ @libertango.id ], body["tracks"].map { it["trackId"] }
  end

  private

  def body
    JSON.parse(response.body)
  end

  def track(title, number)
    Track.create!(title:, track_no: number, disc_no: 1, path: "/music/regina/#{number}.flac", album: @regina)
  end
end
