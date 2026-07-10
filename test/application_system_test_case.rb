require "test_helper"

# The player controls are icon-only buttons: their accessible name is the
# aria-label. If a test can't find it, a screen reader can't either.
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ListeningInABrowser

  DESKTOP = [ 1440, 900 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: DESKTOP

  # Every test in the run shares one browser, so a test that narrows it narrows
  # the next one too. Each says what it needs; a subclass's setup runs after this
  # one and may say otherwise.
  setup do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    page.current_window.resize_to(*DESKTOP)
  end

  # The whole run shares one browser, and the player now writes the queue to
  # localStorage. Left behind, it would ride into the next test's fresh page and
  # be restored under a profile id the rollback handed out again.
  teardown do
    page.execute_script("window.localStorage.clear()")
  rescue StandardError
    # The session never opened a document — there is nothing to leak.
  end
end
