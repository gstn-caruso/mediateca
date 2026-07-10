require "application_system_test_case"

class PlayingMusicTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      genre: "heavy metal", album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    {
      "Dijo El Droguero Al Drogador" => "02 - Dijo el droguero al drogador.flac",
      "Desencuentro" => "01 - Desencuentro.flac",
      "El Pibe Tigre" => "03 - El pibe tigre.flac"
    }.each_with_index do |(title, file), index|
      Track.create!(title:, track_no: index + 1, disc_no: 1, duration: 137.0 + index, path: media(file), album: @album)
    end
  end

  test "the library shows the artists" do
    visit root_path

    assert_text "Your Library"
    assert_text "Almafuerte"
    take_screenshot
  end

  test "an album shows its tracks and can be played" do
    visit album_path(@album)

    assert_text "Mundo Guanaco"
    assert_text "Dijo El Droguero Al Drogador"
    assert_text "2:17"
    take_screenshot
  end

  # The player lives outside the body that Turbo Drive replaces. If the music
  # stopped when navigating, this would catch it.
  test "the music keeps playing when navigating to another page" do
    play "Desencuentro"

    click_link "Mediateca"

    assert_text "Your Library"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
    assert page.evaluate_script("document.querySelector('audio').currentSrc.length > 0"),
      "the <audio> lost its source when navigating"
  end

  test "the track that's playing is marked in the list" do
    play "Desencuentro"

    assert_selector "[data-player-track][aria-current='true']", text: "Desencuentro"
    assert_selector "[data-player-track][aria-current='true']", count: 1
  end

  # Clicking a track queues the whole album: what comes next has to be
  # visible, not just implied.
  test "the queue shows what's next" do
    play "Dijo El Droguero Al Drogador"

    click_button "Queue"

    within "[data-player-target='queue']" do
      assert_text "Desencuentro"
      assert_text "El Pibe Tigre"
      # What already played isn't what's next.
      assert_no_text "Dijo El Droguero Al Drogador"
    end
    take_screenshot
  end

  test "from the queue you can jump to any track" do
    play "Dijo El Droguero Al Drogador"
    click_button "Queue"

    within("[data-player-target='queue']") { click_button "El Pibe Tigre" }

    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  test "next plays the album's next track" do
    play "Dijo El Droguero Al Drogador"

    click_button "Next"

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  # With the queue wrapped around, the last track isn't the end of anything.
  test "with repeat on, the last track loops back to the first" do
    play "El Pibe Tigre"
    click_button "Repeat"

    click_button "Next"

    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
  end

  test "without repeat, the last track is the last one" do
    play "El Pibe Tigre"

    click_button "Next"

    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  test "with shuffle on, what's next stops being the album's order" do
    play "Dijo El Droguero Al Drogador"

    # The record now has its own "Shuffle" button in the header, so ask for the
    # player's toggle by name, not by a label two buttons answer to.
    find("[data-player-target='shuffle']").click

    assert_selector "[data-player-target='shuffle'][aria-pressed='true']"
  end

  # After browsing through half the library, get back to what's playing.
  test "from the player you can get back to the album that's playing" do
    play "Desencuentro"
    click_link "Mediateca"
    assert_text "Your Library"

    click_link "Desencuentro"

    assert_text "Mundo Guanaco"
    assert_selector "[data-player-track][aria-current='true']", text: "Desencuentro"
  end

  # The player lives in the chrome that only a listener sees, so leaving a
  # profile takes the music with it. That is what leaving means.
  test "switching profiles puts the music down" do
    play "Desencuentro"
    assert_selector "audio", visible: :all

    click_on "Switch profile"

    assert_text "Who's listening?"
    assert_no_selector "audio", visible: :all
  end

  # Pressing shuffle on a record is a way of pressing play.
  test "shuffle from the album header turns shuffle on and starts the record" do
    visit album_path(@album)

    click_on "Shuffle Mundo Guanaco"

    assert_selector "[data-player-target='shuffle'][aria-pressed='true']"
    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
  end

  # The search box and Home live in the top bar, reached without looking.
  test "the header searches, and goes home" do
    visit album_path(@album)

    fill_in "Search", with: "Desencuentro"
    find_field("Search").send_keys(:return)
    assert_text "Songs"

    within("header") { click_on "Home" }
    assert_selector "main h1", text: "Your Library"
  end

  private

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
