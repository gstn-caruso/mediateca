require "application_system_test_case"

class PlayingMusicTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
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

    within("#topbar") { click_on "Home" }

    assert_text "Your Library"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
    assert page.evaluate_script("document.querySelector('audio').currentSrc.length > 0"),
      "the <audio> lost its source when navigating"
  end

  # A full reload builds a brand-new <audio>, so the queue that rode on the old
  # one is gone unless it was written down. It was: the browser remembers.
  test "a full refresh keeps what's playing and the queue" do
    play "Dijo El Droguero Al Drogador"

    page.refresh

    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
    assert page.evaluate_script("document.querySelector('audio').currentSrc.length > 0"),
      "the <audio> lost its source across a refresh"

    click_button "Playing Next"
    within "[data-player-target='queue']" do
      assert_text "Desencuentro"
      assert_text "El Pibe Tigre"
    end
  end

  # What the browser remembers is whose it was. Leaving a profile takes the music
  # with it, so the next listener does not inherit the queue left behind.
  test "another profile does not inherit the queue left in the browser" do
    play "Desencuentro"

    switch_profile
    listening_as "Otro"

    assert_selector "[data-player-target='idle']", text: "Nothing playing"
    assert_no_selector "[data-player-target='title']", visible: true
  end

  test "the track that's playing is marked in the list" do
    play "Desencuentro"

    assert_selector "[data-player-track][aria-current='true']", text: "Desencuentro"
    assert_selector "[data-player-track][aria-current='true']", count: 1
  end

  # Clicking a track queues the whole album: what's on now and what comes next
  # both have to be visible, not just implied.
  test "the queue shows what's playing and what's next" do
    play "Dijo El Droguero Al Drogador"

    click_button "Playing Next"

    within "[data-player-target='queue']" do
      # What's on now is named under its own heading...
      assert_text "NOW PLAYING"
      assert_text "Dijo El Droguero Al Drogador"
      # ...and everything still to come under the next.
      assert_text "NEXT UP"
      assert_text "Desencuentro"
      assert_text "El Pibe Tigre"
    end
    take_screenshot
  end

  test "from the queue you can jump to any track" do
    play "Dijo El Droguero Al Drogador"
    click_button "Playing Next"

    # exact: the row also holds a "Remove El Pibe Tigre…" button.
    within("[data-player-target='queue']") { click_button "El Pibe Tigre", exact: true }

    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  test "a track can be dropped from the queue" do
    play "Dijo El Droguero Al Drogador"
    click_button "Playing Next"

    within "[data-player-target='queue']" do
      click_button "Remove Desencuentro from the queue"

      assert_no_text "Desencuentro"
      assert_text "El Pibe Tigre"
    end
  end

  test "next plays the album's next track" do
    play "Dijo El Droguero Al Drogador"

    click_button "Next"

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  # The last track says so: next has nowhere to go, so it goes dim and the end
  # is named out loud.
  test "the last track is the end of the line" do
    play "El Pibe Tigre"

    assert_button "Next", disabled: true
    assert_text "End of playlist"
    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  # After browsing through half the library, get back to what's playing.
  test "from the player you can get back to the album that's playing" do
    play "Desencuentro"
    within("#topbar") { click_on "Home" }
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

    switch_profile

    assert_text "Who's listening?"
    assert_no_selector "audio", visible: :all
  end

  # A record that stops dead at the end of track one is not a music player. This
  # is the loop the whole app exists to run, and nothing was holding it.
  test "when a song ends, the next one starts on its own" do
    play "Dijo El Droguero Al Drogador"

    song_ends

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  # Off, then all, then one. On repeat, the last song is not the end: the record
  # goes back to the top rather than stopping.
  test "on repeat, the record comes back to the top instead of ending" do
    play "El Pibe Tigre"
    assert_button "Next", disabled: true
    click_button "Playing Next"

    click_button "Repeat"

    assert_button "Next", disabled: false
    # The queue says so where it would otherwise have said "Nothing up next."
    assert_text "Repeats from the top."

    song_ends
    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
  end

  test "on repeat one, the song that ends is the song that starts" do
    play "Desencuentro"

    2.times { click_button "Repeat" }
    song_ends

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  test "previous goes back to the song before" do
    play "Desencuentro"

    click_button "Previous"

    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
  end

  # Pressing shuffle on a record is a way of pressing play: the record starts,
  # and the queue behind it is dealt out of order.
  test "shuffle from the album header queues the rest of the record behind it" do
    visit album_path(@album)

    click_on "Shuffle Mundo Guanaco"
    click_button "Playing Next"

    within "[data-player-target='queue']" do
      assert_text "NEXT UP"
      # Two headings, the one on now, and the two still to come: the record is
      # queued behind whatever it started with, not just started.
      assert_selector "li", count: 5
    end
  end

  # Shuffle that always deals the same card first is not shuffle. It used to
  # start at track one every single time — the one song a listener would notice.
  test "shuffle does not always start the record at the same song" do
    visit album_path(@album)

    started = 10.times.map do
      click_on "Shuffle Mundo Guanaco"
      find("[data-player-target='titleText']").text
    end

    assert_operator started.uniq.size, :>, 1,
      "ten shuffles all started with #{started.first}: the deal is fixed"
  end

  # The bouncing bars say sound is coming out of this song. On pause, no sound
  # is coming out of anything, and an equalizer that keeps dancing is a lie.
  test "the equalizer holds still while the music is paused" do
    play "Desencuentro"
    assert_equal "running", equalizer_state

    click_button "Play or pause"

    # The play icon coming back is the music having stopped; the bars have to
    # have stopped with it.
    assert_selector "[data-player-target='playIcon']", visible: true
    assert_equal "paused", equalizer_state
  end

  # The search box and Home live in the top bar, reached without looking.
  test "the header searches, and goes home" do
    visit album_path(@album)

    fill_in "Search", with: "Desencuentro"
    find_field("Search").send_keys(:return)
    assert_text "Songs"

    within("#topbar") { click_on "Home" }
    assert_selector "main h1", text: "Your Library"
  end

  private

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  # A song running out is not a button anybody presses, and it is the one thing
  # a player has to get right. The fixture FLACs are 50 bytes, so the only way
  # to reach the end of one is to say it reached the end.
  def song_ends
    page.execute_script("document.querySelector('audio').dispatchEvent(new Event('ended'))")
  end

  # Whether the bars are actually moving, as the browser has it — not whether we
  # remembered to write a class.
  def equalizer_state
    page.evaluate_script("getComputedStyle(document.querySelector('.eq > i')).animationPlayState")
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
