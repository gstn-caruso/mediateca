require "test_helper"

# What a record is, as files. The rows already say it song by song; the head of
# the page says it once, for the record — which is the question actually being
# asked when somebody opens it: is this the good copy?
class AlbumTest < ActiveSupport::TestCase
  setup { @artist = Artist.create!(name: "Elliott Smith") }

  test "a record ripped lossless all the way through says so" do
    record(%w[flac flac flac])

    assert_equal "FLAC", @album.quality
  end

  test "a record compressed all the way through says how hard" do
    record(%w[mp3 mp3], bit_rate: 320_000)

    assert_equal "MP3 · 320", @album.quality
  end

  # Half a record ripped from the CD and half filled in off the internet is not
  # one thing, and there is no honest badge for it. It says nothing, and the rows
  # go on saying the truth song by song.
  test "a record that is two things at once says nothing" do
    record(%w[flac opus])

    assert_nil @album.quality
  end

  # A record scanned before we recorded encodings has nothing to say about itself.
  test "a record nobody measured says nothing" do
    record([ nil, nil ])

    assert_nil @album.quality
  end

  test "a record with no songs on it yet says nothing" do
    record([])

    assert_nil @album.quality
  end

  private

  def record(codecs, bit_rate: nil)
    @album = Album.create!(directory: "/music/#{SecureRandom.hex(4)}", title: "Figure 8", artist: @artist)
    codecs.each_with_index do |codec, index|
      Track.create!(title: "Song #{index}", track_no: index + 1, disc_no: 1,
                    path: "/music/#{index}.#{codec}", album: @album, codec:, bit_rate:)
    end
    @album
  end
end
