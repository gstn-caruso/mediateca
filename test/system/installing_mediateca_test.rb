require "application_system_test_case"

# Capybara serves the app from 127.0.0.1, and a browser counts that as a secure
# context with no certificate anywhere in sight. So the worker registers here
# exactly as it will on the NAS behind HTTPS — what this test watches is the real
# thing, not a stand-in for it.
class InstallingMediatecaTest < ApplicationSystemTestCase
  setup do
    listening_as
  end

  # A worker that registers but never controls the page is a worker that will not
  # be there on the day the server isn't.
  test "the worker takes control of the window" do
    visit root_path

    assert worker_in_control, "the service worker never took control of the page"
  end

  # Everything else the worker touches, it touches by leaving alone — the covers,
  # the searches, and above all the FLAC, which is asked for one byte range at a
  # time. That it doesn't break any of them is what the rest of this suite says:
  # every system test now runs with the worker registered and in control.

  private
    def worker_in_control
      page.evaluate_async_script(<<~JS)
        const done = arguments[0]
        navigator.serviceWorker.ready
          .then(() => navigator.serviceWorker.controller
            ? true
            : new Promise((resolve) => navigator.serviceWorker.addEventListener(
                "controllerchange", () => resolve(true), { once: true })))
          .then(done, () => done(false))
      JS
    end
end
