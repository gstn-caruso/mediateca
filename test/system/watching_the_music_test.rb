require "application_system_test_case"

# Only the tests that are about the sound put a song on. The others — the rail,
# the presets, the screen, the visit — are answered by a picture standing still,
# and a picture standing still is one frame.
#
# A moving one is sixty a second, drawn on the CPU here because the runner has no
# card to draw them with, and it drowns the browser it is drawn in: Selenium's own
# questions started timing out, in a different test each run. The machine this is
# looked at on has a card and never notices. The runner does, so it is not asked to.
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
    visit root_path
    click_button "Visualizer"
    assert_selector "#visualizer-panel"

    click_button "Visualizer"

    assert_no_selector "#visualizer-panel"
  end

  # Milkdrop is not one picture, it is thousands of them, and each one is
  # somebody's. So the rail says whose you are looking at.
  test "the picture on the wall says which one it is" do
    visit root_path

    click_button "Visualizer"

    assert_selector PRESET, text: /\S/
  end

  # Twenty years of presets, and the only way through them anybody ever wanted:
  # the arrow keys.
  test "the arrows walk through the presets" do
    visit root_path
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

  # Nobody walked the presets by hand for twenty years. Milkdrop picked its own
  # every few minutes, and that is most of what made it a thing to leave running
  # rather than a thing to operate — you put it on and the wall keeps changing.
  test "the picture picks a new preset on its own" do
    play "Desencuentro"
    a_preset_lasts 500
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    draw_nothing
    first = find(PRESET).text

    assert_no_selector PRESET, exact_text: first
  end

  # And the minutes are the music's, not the wall's. A song paused over lunch
  # leaves the picture on exactly the preset it stopped on: nothing is drawn, so
  # nothing is spent, and coming back to a different wall than the one you left
  # would be the app having a go at Milkdrop while nobody was listening.
  test "a picture that has stopped keeps the preset it stopped on" do
    play "Desencuentro"
    a_preset_lasts 500
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    draw_nothing
    pause
    stopped_on = find(PRESET).text

    sleep 1.5

    assert_selector PRESET, exact_text: stopped_on
  end

  # Arrows are for the presets, but only once the picture is up: typing a search
  # is the same keyboard, and a caret has to be able to move through a word.
  test "the arrows are the search box's while you are typing in it" do
    visit root_path
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    first = find(PRESET).text

    find("input[aria-label='Search']").send_keys("guanaco", :arrow_left)

    assert_selector PRESET, exact_text: first
  end

  # Where this was always going. And what goes full screen is the picture, not a
  # canvas with a window's worth of chrome still stuck to the top of it — so the
  # header goes with it, and Escape is the way back, as it is out of every full
  # screen there ever was.
  test "the picture can take the whole screen, and nothing else goes with it" do
    visit root_path
    click_button "Visualizer"
    assert_selector ".visualizer-chrome"
    assert_selector PRESET, text: /\S/
    count_the_frames
    so_far = frames_so_far

    click_button "Full screen"

    assert_no_selector ".visualizer-chrome"
    assert_equal "visualizer-panel", page.evaluate_script("document.fullscreenElement?.id")
    assert_selector "button[aria-label='Full screen'][aria-pressed='true']", visible: :all

    # Resizing a canvas empties it. With the music running the next frame is a
    # sixtieth of a second away and nobody ever sees it happen — but this picture
    # is stopped, and a stopped picture thrown across the screen would arrive there
    # black, or stretched out of the shape of the rail it used to be in.
    #
    # Counted from before the screen was asked for: the picture is put back on the
    # instant the canvas is resized, and a window that opens after that has missed it.
    assert eventually { frames_so_far > so_far }, "the picture went black on its way to the screen"
  end

  # Full screen there is nothing left in the room but the picture. The pill that
  # says what is playing is behind it, on a page nobody can see — so across the
  # room somebody asks what this is, and the answer is on a screen you have to
  # come out of full screen to read.
  #
  # So it is said over the picture, where every full screen player has always said
  # it: the sleeve, the song, and whose it is, down in the corner.
  test "full screen says what is playing over the picture" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    click_button "Full screen"

    within BILLING do
      assert_text "Desencuentro"
      assert_text "Almafuerte"
    end
  end

  # And the sleeve up there is not the sleeve in the pill. The pill's is a
  # forty-pixel thumb; this one is a hand's width of screen, and handed the thumb
  # it would be a hand's width of mush. It takes the big one — the same picture a
  # phone puts on its lock screen.
  test "the sleeve over the picture is the big one, not the pill's thumb" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    click_button "Full screen"

    assert_selector "#{BILLING} img[src*='size=#{Music::Thumbnail::SIZES.max}']"
  end

  # In its rail it says none of it. The rail is a postage stamp with the pill
  # sitting under it saying all of this already, and a second copy of it printed
  # over the picture would be covering the only thing the rail is for.
  test "the picture in its rail says nothing about what is playing" do
    play "Desencuentro"

    click_button "Visualizer"

    assert_selector PRESET, text: /\S/
    assert_no_selector BILLING
  end

  # Milkdrop does not own the canvas it draws on: it sizes its own framebuffers,
  # aims at them, and draws. A canvas nobody has sized is 300×150 — that is simply
  # what a canvas is — and the picture came out drawn through a letterbox and
  # stretched over the rail. Nothing in the page said so; it just looked wrong.
  #
  # And then, on a retina screen only, it looked wrong a second way: the canvas was
  # the right size and Milkdrop was aiming at a quarter of it, so the picture sat
  # in the bottom corner of its own rail. Two numbers have to agree, and a screen
  # that draws two pixels where it says one is the whole reason they can differ —
  # so this asks on such a screen, which is the screen this is looked at on.
  #
  # No song, on purpose. What is asked here is where Milkdrop aims, and it aims
  # the moment the rail opens — a still picture answers it as well as a moving one.
  # A moving one, four times the pixels because of the retina, drawn on a runner
  # that has no GPU to draw it with, answers it while holding the whole browser
  # under: it timed out mid-question.
  test "the picture is drawn at the size of the rail, and fills it" do
    retina
    visit root_path
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    aim = eventually { canvas_aim if canvas_aim[:canvas] != BARE_CANVAS }

    assert_equal [ aim[:rail][0] * 2, aim[:rail][1] * 2 ], aim[:canvas], "the canvas is not the size of the rail"
    assert_equal aim[:canvas], aim[:aimed_at], "Milkdrop is not aiming at the whole canvas"
  end

  # Stopping is not the same as stopping watching. A rail that is open is a rail
  # that can be resized — the window is dragged, the sidebar folds — and a picture
  # standing still has to be told, or it stands there stretched into a shape that
  # is not its own. The picture stops. The tape measure does not.
  test "a picture standing still still follows the size of its rail" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    pause
    was = canvas_aim[:rail]

    page.current_window.resize_to(1100, 780)

    eventually { canvas_aim[:rail] != was }
    sleep 0.3
    aim = canvas_aim

    assert_equal aim[:rail], aim[:canvas], "the picture is stretched over a rail that changed size under it"
  ensure
    page.current_window.resize_to(*DESKTOP)
  end

  # A picture of the music, drawn while there is no music, is a picture of nothing
  # — and it was still churning away at sixty frames a second over a song that had
  # been paused for ten minutes. Stopped, it holds the last frame it drew, which is
  # what a paused thing looks like.
  test "the picture stops when the song stops, and picks up when it starts" do
    play "Desencuentro"
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    count_the_frames

    assert_operator frames_drawn, :>, 0, "the picture never moved while the song played"

    pause

    assert_equal 0, frames_drawn, "the picture kept moving after the song stopped"

    unpause

    assert_operator frames_drawn, :>, 0, "the picture did not pick the song back up"
  end

  # The rail is permanent, like the <audio> under it. Browsing to somewhere else
  # does not take the picture down and put a new one up: behind that canvas is a
  # live WebGL context and a graph tapped off the music, and neither is a thing to
  # build again because somebody clicked on a record. The preset it was already
  # wearing is how you can tell it is the same picture and not a new one — a rebuilt
  # one would have reached into the thousands and come back wearing something else.
  test "the picture rides through a visit" do
    visit album_path(@album)
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/
    was = find(PRESET).text

    click_link "Home"
    assert_text "Your Library"

    assert_selector "#visualizer-panel canvas"
    assert_selector PRESET, exact_text: was
  end

  test "putting the picture up does not take the music away" do
    play "Desencuentro"

    click_button "Visualizer"
    assert_selector "#visualizer-panel canvas"

    assert page.evaluate_script("!document.querySelector('audio').paused"), "the music stopped"
  end

  # The one that matters, and the one nothing else would catch.
  #
  # To draw the music the picture has to hear it, and the only way to hear an
  # <audio> is to stand in the middle of it: the sound is taken off the element
  # and handed to the graph. Which leaves the graph owing the speakers their sound
  # back. Forget that one line and everything here still passes — the song still
  # plays, the picture still comes up, the rail still says which preset it is —
  # and the house is silent. No test can hear, so this one asks the browser to
  # show its wiring instead.
  test "the sound the picture borrows is given back to the speakers" do
    play "Desencuentro"
    watch_the_wiring

    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    assert_includes wiring, [ "MediaElementAudioSourceNode", "AudioDestinationNode" ]
    # And the other half of it: the picture is drawn from the song, not from nothing.
    assert_includes wiring.map(&:first), "MediaElementAudioSourceNode"
    assert_includes wiring.map(&:last), "AnalyserNode"
  end

  # The one that actually took the music away, in the house, on the real thing.
  #
  # A browser will not let a page nobody has touched make a sound. That is why an
  # AudioContext is born asleep, and it is why the rail — which is remembered, and
  # so opens itself on the next load, which is nobody pressing anything — builds
  # its graph asleep. The music is routed through that graph the moment the picture
  # taps the <audio>, and the graph was tapped once and never spoken to again. So
  # the song runs, the clock ticks, the picture moves, every test passes, and the
  # house is silent.
  #
  # Headless Chrome will make any sound for anybody and never sleeps, so it cannot
  # be asked whether this would have happened — asking it to enforce the rule does
  # nothing. It is put to sleep by hand instead, which is precisely what the real
  # browser was doing, and then the music is started the way a hand starts it.
  test "a sleeping graph wakes when the music does" do
    visit album_path(@album)
    click_button "Visualizer"
    assert_selector PRESET, text: /\S/

    doze_off
    assert_equal "suspended", audio_graph_state

    find("button[data-player-track]", text: "Desencuentro").click
    assert_selector "[data-player-target='title']", text: "Desencuentro"

    assert graph_awake?, "the song is playing into a graph that is #{audio_graph_state}: the house is silent"
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

  # What is playing, printed over the picture — and only over a picture that has
  # the whole screen.
  BILLING = ".visualizer-billing".freeze

  # What a <canvas> measures when nobody has ever told it otherwise.
  BARE_CANVAS = [ 300, 150 ].freeze

  # A preset's turn is five minutes, and nobody is sitting in front of a test for
  # five minutes. The rail carries the number rather than hiding it in the
  # JavaScript, so the test can turn it down to something it can watch.
  def a_preset_lasts(ms)
    page.execute_script("document.getElementById('visualizer-panel').dataset.visualizerTurnValue = #{ms}")
  end

  # Milkdrop, emptied out, with the loop it is drawn in left running.
  #
  # A preset's turn is spent by the frames the picture draws, so a test about the
  # clock has to have the picture actually moving — and on this runner moving is
  # the expensive part: a thousand shader instructions a pixel, rasterised on a
  # CPU, sixty times a second, in one of four browsers sharing two cores. Left to
  # draw for real, these two took the browser down far enough that OTHER tests
  # failed — a pause that was never seen, a graph that never finished being built.
  #
  # What is under test is the counting, and the counting happens in the loop. So
  # the loop is left exactly as it is and the picture inside it is emptied: every
  # frame still comes, and every one of them costs nothing.
  def draw_nothing
    page.execute_script("document.querySelector('#visualizer-panel canvas').show.visualizer.render = () => {}")
  end

  # Every wire the page is about to run, taken down as it is run. Web Audio will
  # not say afterwards what is plugged into what, so it is asked on the way past.
  # Set before the rail is ever opened — the graph is built the first time it is.
  def watch_the_wiring
    page.execute_script(<<~JS)
      window.wiring = []
      const connect = AudioNode.prototype.connect
      AudioNode.prototype.connect = function (to, ...rest) {
        window.wiring.push([ this.constructor.name, to?.constructor?.name ?? String(to) ])
        return connect.call(this, to, ...rest)
      }
    JS
  end

  def wiring
    eventually { page.evaluate_script("window.wiring").presence }
  end

  # The screen this is actually looked at on: two pixels for every one it admits to.
  def retina
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: DESKTOP[0], height: DESKTOP[1], deviceScaleFactor: 2, mobile: false)
  end

  # The rail, the canvas the rail was given, and the corner of it Milkdrop is
  # actually aiming at. All three have to be the same picture.
  def canvas_aim
    page.evaluate_script(<<~JS).symbolize_keys
      (() => {
        const canvas = document.querySelector("#visualizer-panel canvas")
        const gl = canvas.getContext("webgl2")
        const viewport = gl.getParameter(gl.VIEWPORT)
        return {
          rail: [ canvas.clientWidth, canvas.clientHeight ],
          canvas: [ canvas.width, canvas.height ],
          aimed_at: [ viewport[2], viewport[3] ]
        }
      })()
    JS
  end

  # Milkdrop draws by asking WebGL to draw, so WebGL is where you count. Every
  # frame is many of these; none at all is a picture that has stopped.
  #
  # Both ways of asking. Which one a frame uses is the preset's business — the warp
  # mesh goes through an index buffer and the shapes and waves do not — and the
  # preset is picked out of a hat. Counting only one of them counted some presets
  # and not others, which is a coin toss wearing a lab coat.
  def count_the_frames
    page.execute_script(<<~JS)
      window.drawn = 0
      for (const asking of [ "drawArrays", "drawElements" ]) {
        const draw = WebGL2RenderingContext.prototype[asking]
        WebGL2RenderingContext.prototype[asking] = function (...call) {
          window.drawn++
          return draw.apply(this, call)
        }
      }
    JS
  end

  # A graph that is not running is a graph making no sound, and the music goes
  # through it the moment the picture taps the <audio>.
  def audio_graph_state
    page.evaluate_script("document.querySelector('audio').tap?.context?.state ?? 'never tapped'")
  end

  # What the browser does on its own to a page nobody has touched.
  def doze_off
    page.execute_script("document.querySelector('audio').tap.context.suspend()")
    eventually { audio_graph_state == "suspended" }
  end

  def graph_awake?
    Timeout.timeout(3) { sleep 0.1 until audio_graph_state == "running" }
    true
  rescue Timeout::Error
    false
  end

  def frames_so_far
    page.evaluate_script("window.drawn")
  end

  # What was drawn over the last three quarters of a second — which, for a picture
  # that has stopped, is nothing.
  def frames_drawn
    before = frames_so_far
    sleep 0.75
    frames_so_far - before
  end

  # Pressing the button is not the same as the song hearing it, and the frames of
  # the gap between the two belong to the song that was still playing. The player
  # turns the button over when the <audio> tells it the music has stopped, and the
  # picture is told in the same breath — so the icon is the news, and counting
  # starts after it.
  def pause
    click_button "Play or pause"
    assert_selector "[data-player-target='playIcon']", visible: true
  end

  def unpause
    click_button "Play or pause"
    assert_selector "[data-player-target='pauseIcon']", visible: true
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
