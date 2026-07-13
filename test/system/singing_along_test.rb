require "application_system_test_case"

class SingingAlongTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    {
      "Desencuentro" => "01 - Desencuentro.flac",
      "El Pibe Tigre" => "03 - El pibe tigre.flac"
    }.each_with_index do |(title, file), index|
      Track.create!(title:, track_no: index + 1, disc_no: 1, duration: 30.0, path: media(file), album: @album)
    end
  end

  # Where it was asked for: beside the queue, and before it.
  test "the way to the words is next to the way to the queue" do
    visit root_path

    labels = all("#topbar button[aria-label]").map { it[:"aria-label"] }

    assert_operator labels.index("Lyrics"), :<, labels.index("Playing Next")
  end

  test "the rail shows the words of what is playing" do
    play "Desencuentro"

    click_button "Lyrics"

    within "[data-player-target='lyrics']" do
      assert_text "La primera línea"
      assert_text "La tercera línea"
    end
    take_screenshot
  end

  # The whole point of a timed .lrc: the line being sung is the line lit up, and
  # it moves on its own as the song runs.
  test "the line being sung is the line lit up" do
    play "Desencuentro"
    click_button "Lyrics"

    sung_to 3.5

    assert_selector "#{LINES}[aria-current='true']", text: "La segunda línea"
    assert_selector "#{LINES}[aria-current='true']", count: 1
  end

  # The timed silence between the verses is where the karaoke has nothing to
  # point at, and pointing at the last line through it would be a lie.
  test "in the gap between verses nothing is lit" do
    play "Desencuentro"
    click_button "Lyrics"

    sung_to 5.5

    assert_no_selector "#{LINES}[aria-current='true']"
  end

  # Following is a choice. Turned off, the words stand still and you read them
  # yourself — and the choice outlives the page, like every other one here.
  test "the words can be left to stand still" do
    play "Desencuentro"
    click_button "Lyrics"
    sung_to 3.5
    assert_selector "#{LINES}[aria-current='true']", text: "La segunda línea"

    click_button "Follow the song"

    sung_to 7.5
    assert_no_selector "#{LINES}[aria-current='true']"

    page.refresh
    sung_to 7.5
    assert_no_selector "#{LINES}[aria-current='true']", visible: :all
  end

  # And turned back on it catches up with wherever the song got to, rather than
  # waiting for the next line to come round.
  test "following again picks the song up where it is" do
    play "Desencuentro"
    click_button "Lyrics"
    click_button "Follow the song"
    sung_to 7.5

    click_button "Follow the song"

    assert_selector "#{LINES}[aria-current='true']", text: "La tercera línea"
  end

  # 126 of the 1590 songs on the disk have no .lrc beside them. The microphone
  # opens the words, so on one of those there is nothing for it to open, and it
  # goes dead rather than opening onto a rail with nothing in it.
  test "a song nobody wrote the words for leaves the microphone dead" do
    play "El Pibe Tigre"

    assert_button "Lyrics", disabled: true
  end

  test "a song somebody did write them for leaves the microphone alive" do
    play "Desencuentro"

    assert_button "Lyrics", disabled: false
  end

  # No song is no words either.
  test "with nothing playing there is nothing to open" do
    visit root_path

    assert_button "Lyrics", disabled: true
  end

  # The rail was opened on a song that had words, and the next one has none. It
  # has nothing left to show — and the button that would shut it has just gone
  # dead — so it shuts itself.
  test "a song with no words shuts the rail behind it" do
    play "Desencuentro"
    click_button "Lyrics"
    assert_selector "#lyrics-panel"

    find("button[data-player-track]", text: "El Pibe Tigre").click

    assert_no_selector "#lyrics-panel"
    assert_button "Lyrics", disabled: true
  end

  # An empty queue is not a song without words. The rail was left open, and it
  # stays open and says why it is empty: shutting it here would throw away the
  # choice to have it open at all, on nothing more than having pressed nothing yet.
  test "a rail left open with nothing playing says so and stays open" do
    visit root_path
    page.execute_script("window.localStorage.setItem('mediateca:lyrics', 'open')")

    visit root_path

    assert_selector "#lyrics-panel"
    within("[data-player-target='lyrics']") { assert_text "Nothing playing" }
    assert_button "Lyrics", disabled: true
  end

  private

  LINES = "[data-player-target='lyrics'] [data-at]".freeze

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  # The fixture FLACs are 30 seconds of silence, and a test cannot sit through
  # even that. So the song is told where it got to, the way `ended` is told.
  def sung_to(seconds)
    page.execute_script(<<~JS)
      const audio = document.querySelector("audio")
      audio.currentTime = #{seconds}
      audio.dispatchEvent(new Event("timeupdate"))
    JS
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
