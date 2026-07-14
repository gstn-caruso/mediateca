require "test_helper"

# Pressing play somewhere that is not the record's own page: a row in the rail, an
# artist's header. The queue has always been filled from the song rows on the page
# — and there are none of those here. So the record is asked for its songs.
#
# The answer is spelled exactly the way a row spells one, because it is the same
# queue: a record put on from the rail has to behave like a record put on from its
# own tracklist, down to the colour it paints the app.
class PuttingARecordOnTest < ActionDispatch::IntegrationTest
  setup do
    listening_as
    @artist = Artist.create!(name: "Elliott Smith")
    @xo = record("XO", 1998, [ "Sweet Adeline" ])
    @figure_8 = record("Figure 8", 2000, [ "Son of Sam", "Junk Bond Trader" ])
  end

  test "a record hands over its songs, in the order it was pressed" do
    get album_queue_path(@figure_8)

    assert_response :success
    assert_equal [ "Son of Sam", "Junk Bond Trader" ], titles
  end

  # The player reads a row's dataset, and the DOM camelCases what it dasherizes.
  # An answer spelled any other way is a queue of tracks with no source and no
  # title.
  test "a song is spelled the way the player writes one down" do
    get album_queue_path(@figure_8)

    assert_equal %w[trackId src title subtitle cover artwork album albumTitle palette],
      response.parsed_body["tracks"].first.keys
  end

  # The colour goes with the songs. A record put on from the rail paints the app
  # its own colour before its cover has even been asked for — the same as one put
  # on from its own page.
  test "a song carries the colour of the record it is on" do
    @figure_8.update!(accent: "#c8102e")

    get album_queue_path(@figure_8)

    assert_equal @figure_8.palette.to_h.to_json, response.parsed_body["tracks"].first["palette"]
  end

  # Putting an artist on is putting their shelf on: everything they made, oldest
  # record first, each one in its running order.
  test "an artist hands over everything they made, oldest record first" do
    get artist_queue_path(@artist)

    assert_equal [ "Sweet Adeline", "Son of Sam", "Junk Bond Trader" ], titles
  end

  test "nobody who is not listening is handed a queue" do
    delete session_path

    get album_queue_path(@figure_8)

    assert_redirected_to profiles_path
  end

  private

  def titles
    response.parsed_body["tracks"].map { |song| song["title"] }
  end

  def record(title, year, songs)
    album = Album.create!(directory: "/music/#{title}", title:, year:, artist: @artist)
    songs.each_with_index do |song, index|
      Track.create!(title: song, track_no: index + 1, disc_no: 1, path: "/music/#{song}.flac", album:)
    end
    album
  end
end
