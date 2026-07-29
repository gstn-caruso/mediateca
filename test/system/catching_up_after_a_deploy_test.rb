require "application_system_test_case"

class CatchingUpAfterADeployTest < ApplicationSystemTestCase
  setup do
    listening_as
    @was = Rails.configuration.x.build
  end

  teardown { Rails.configuration.x.build = @was }

  # A deploy takes the socket down with it — the container holding the connection
  # is the one being replaced — so the tab is never listening at the moment the
  # new build announces itself. It is reconnecting. Coming back is therefore the
  # question worth asking: did I miss one?
  test "a tab that lost its socket to a deploy comes back onto the new build" do
    visit root_path
    assert_text "Your Library"

    # The deploy: a new build is answering now, and the socket the tab was
    # holding died with the container that is being replaced.
    Rails.configuration.x.build = "a-build-that-was-not-here-before"

    page.execute_script(%(addEventListener("turbo:morph", () => document.documentElement.dataset.morphed = "true")))

    # The socket dies with the container being replaced...
    page.execute_script(%(document.querySelector("turbo-cable-stream-source").removeAttribute("connected")))
    # ...and, a moment later, finds its way back — to a different build.
    page.execute_script(%(document.querySelector("turbo-cable-stream-source").setAttribute("connected", "")))

    assert_selector "html[data-morphed='true']", visible: :all, count: 1
  end

  # And it does not refresh for the sake of it: a socket that drops and comes back
  # for any other reason — the wifi, a sleeping laptop — finds the same build
  # underneath and leaves the page alone.
  test "a socket that comes back to the same build leaves the page alone" do
    visit root_path
    assert_text "Your Library"

    page.execute_script(<<~JS)
      window.refreshed = false
      addEventListener("turbo:morph", () => window.refreshed = true)
      addEventListener("turbo:visit", () => window.refreshed = true)
    JS

    page.execute_script(%(document.querySelector("turbo-cable-stream-source").removeAttribute("connected")))
    page.execute_script(%(document.querySelector("turbo-cable-stream-source").setAttribute("connected", "")))

    # The tab asks /build the moment it hears the socket come back — before this
    # line, over a connection that has had the time an actual WebDriver round
    # trip takes to be opened. Asking it again ourselves and letting a macrotask
    # turn pass after is proof that ask has been answered and acted on, not a
    # guess at how long asking takes.
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]
      fetch("/build", { cache: "no-store" })
        .then(() => new Promise((resolve) => setTimeout(resolve, 0)))
        .then(done)
    JS

    assert_not page.evaluate_script("window.refreshed"),
      "the page refreshed itself over nothing: the build underneath it never changed"
  end
end
