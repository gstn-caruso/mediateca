require "test_helper"

# The badge is the only place the scan's measurements ever surface, and the only
# test that draws it.
class SeeingHowGoodAFileIsTest < ActionDispatch::IntegrationTest
  setup do
    listening_as
    @album = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist: Artist.create!(name: "Almafuerte"))
  end

  # A lossless file kept every sample, so its name is the whole claim: no
  # numbers, and nothing to say about a bitrate it never chose.
  test "a lossless track wears its format, and nothing else" do
    track "Zamba de resurreccion", codec: "flac", bit_depth: 24, sample_rate: 192000

    get album_path(@album)

    assert_select "span", text: "FLAC"
    assert_select "[data-bit-rate-mode]", count: 0
    assert_no_match "24/192", response.body
  end

  # A compressed file is only as good as the bits it was given, so it says how
  # many — and shows, without a word, whether it held that number or let it
  # follow the music.
  test "a compressed track shows its bits, and how it spent them" do
    track "Sé vos", codec: "mp3", bit_rate: 320000, bit_rate_mode: "constant"

    get album_path(@album)

    assert_select "span", text: "MP3 · 320"
    assert_select "[data-bit-rate-mode='constant']"
  end

  test "a bitrate that followed the music draws a different icon" do
    track "A vos amigo", codec: "mp3", bit_rate: 128000, bit_rate_mode: "variable"

    get album_path(@album)

    assert_select "[data-bit-rate-mode='variable']"
    assert_select "[data-bit-rate-mode='constant']", count: 0
  end

  # Scanned before we recorded encodings: no badge rather than an empty one.
  test "a track nobody measured wears no badge" do
    track "Vientos de poder"

    get album_path(@album)

    assert_select "[data-bit-rate-mode]", count: 0
    assert_select "span[title]", text: /MP3|FLAC/, count: 0
  end

  # Song by song is how the truth is told, but it is not how the question is
  # asked. Somebody opening a record wants to know whether this is the good copy,
  # and reading twenty rows to find out is not an answer.
  test "a record that is one thing all the way through says so at its head" do
    track "Zamba de resurreccion", codec: "flac", bit_depth: 24, sample_rate: 192000
    track "Sé vos", codec: "flac", bit_depth: 24, sample_rate: 192000

    get album_path(@album)

    assert_select "header", text: /FLAC/
  end

  # A folder half ripped from the CD and half filled in off the internet is not
  # one thing, and there is no honest badge for it.
  test "a record that is two things at once says nothing at its head" do
    track "Zamba de resurreccion", codec: "flac"
    track "Sé vos", codec: "mp3", bit_rate: 128000

    get album_path(@album)

    assert_select "header", text: /FLAC|MP3/, count: 0
  end

  private

  def track(title, **audio)
    Track.create!(title:, path: "#{@album.directory}/#{title}.flac", album: @album, **audio)
  end
end
