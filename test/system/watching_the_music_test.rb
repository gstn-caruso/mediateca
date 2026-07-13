require "application_system_test_case"

class WatchingTheMusicTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(
      title: "Desencuentro", track_no: 1, disc_no: 1, duration: 137.0,
      path: media("01 - Desencuentro.flac"), album: @album
    )
  end

  # Where it was asked for: on the microphone's left. The bar reads
  # picture, words, queue — the three things a song can open onto.
  test "the way to the picture is next to the way to the words" do
    visit root_path

    labels = all("#topbar button[aria-label]").map { it[:"aria-label"] }

    assert_operator labels.index("Visualizer"), :<, labels.index("Lyrics")
  end

  test "the rail draws what is playing" do
    play "Desencuentro"

    click_button "Visualizer"

    assert_selector "#visualizer-panel canvas"
    take_screenshot
  end

  test "the rail shuts the way it opened" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector "#visualizer-panel"

    click_button "Visualizer"

    assert_no_selector "#visualizer-panel"
  end

  # Milkdrop is not one picture, it is thousands of them, and each one is
  # somebody's. So the rail says whose you are looking at.
  test "the picture on the wall says which one it is" do
    play "Desencuentro"

    click_button "Visualizer"

    assert_selector PRESET, text: /\S/
  end

  # Twenty years of presets, and the only way through them anybody ever wanted:
  # the arrow keys.
  test "the arrows walk through the presets" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    first = find(PRESET).text

    press :arrow_right

    assert_no_selector PRESET, exact_text: first
    second = find(PRESET).text

    press :arrow_left

    assert_selector PRESET, exact_text: first
    refute_equal first, second
  end

  # Arrows are for the presets, but only once the picture is up: typing a search
  # is the same keyboard, and a caret has to be able to move through a word.
  test "the arrows are the search box's while you are typing in it" do
    play "Desencuentro"
    click_button "Visualizer"
    first = find(PRESET).text

    find("input[aria-label='Search']").send_keys("guanaco", :arrow_left)

    assert_selector PRESET, exact_text: first
  end

  # Where this was always going. And what goes full screen is the picture, not a
  # canvas with a window's worth of glass still stuck to the top of it — so the
  # header goes with it, and Escape is the way back, as it is out of every full
  # screen there ever was.
  test "the picture can take the whole screen, and nothing else goes with it" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector ".visualizer-chrome"

    click_button "Full screen"

    assert_no_selector ".visualizer-chrome"
    assert_equal "visualizer-panel", page.evaluate_script("document.fullscreenElement?.id")
    assert_selector "button[aria-label='Full screen'][aria-pressed='true']", visible: :all
  end

  # Milkdrop does not own the canvas it draws on: it sizes its own framebuffers,
  # aims at them, and draws. A canvas nobody has sized is 300×150 — that is simply
  # what a canvas is — and the picture came out drawn through a letterbox and
  # stretched over the rail. Nothing in the page said so; it just looked wrong.
  test "the picture is drawn at the size of the rail, not the size of a bare canvas" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    drawn = eventually { canvas_size[:drawn] if canvas_size[:drawn] != BARE_CANVAS }

    assert_equal canvas_size[:laid_out], drawn
  end

  # The rail is permanent, like the <audio> under it. Browsing to somewhere else
  # does not take the picture down and put a new one up: behind that canvas is a
  # live WebGL context and a graph tapped off the music, and neither is a thing to
  # build again because somebody clicked on a record. The preset it was already
  # wearing is how you can tell it is the same picture and not a new one.
  test "the picture rides through a visit" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    was = find(PRESET).text

    click_link "Home"
    assert_text "Your Library"

    assert_selector "#visualizer-panel canvas"
    assert_selector PRESET, exact_text: was
  end

  # The one that matters. A visualizer has to listen to the music to draw it, and
  # the way it listens is by putting itself in the middle of the audio — between
  # the file and the speakers. Done wrong, the picture comes up beautifully and
  # the house goes silent.
  test "putting the picture up does not take the music away" do
    play "Desencuentro"

    click_button "Visualizer"
    assert_selector "#visualizer-panel canvas"

    assert page.evaluate_script("!document.querySelector('audio').paused"), "the music stopped"
  end

  # Left open, it is still open next time — the way the queue and the words are.
  test "a rail left open comes back open" do
    visit root_path
    page.execute_script("window.localStorage.setItem('mediateca:visualizer', 'open')")

    visit root_path

    assert_selector "#visualizer-panel canvas"
  end

  private

  PRESET = "[data-visualizer-target='preset']".freeze

  # What a <canvas> measures when nobody has ever told it otherwise.
  BARE_CANVAS = [ 300, 150 ].freeze

  # What Milkdrop is drawing, and what the rail actually gave it to draw on.
  def canvas_size
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const canvas = document.querySelector("#visualizer-panel canvas")
        const sharpness = Math.min(window.devicePixelRatio || 1, 2)
        return {
          drawn: [ canvas.width, canvas.height ],
          laid_out: [ Math.round(canvas.clientWidth * sharpness), Math.round(canvas.clientHeight * sharpness) ]
        }
      })()
    JS
  end

  # The finders wait; evaluate_script does not, and the picture is raised on a
  # promise — a megabyte of presets has to come down the wire first.
  def eventually
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop do
        found = yield
        return found if found

        sleep 0.1
      end
    end
  rescue Timeout::Error
    flunk "waited #{Capybara.default_max_wait_time}s and it never happened"
  end

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  # Where the focus actually is — which, after clicking the button that opened
  # the rail, is that button. That is the real hand on the real keyboard.
  def press(key)
    page.driver.browser.action.send_keys(key).perform
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
