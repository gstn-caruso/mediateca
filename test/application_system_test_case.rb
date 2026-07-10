require "test_helper"

# The player controls are icon-only buttons: their accessible name is the
# aria-label. If a test can't find it, a screen reader can't either.
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ListeningInABrowser

  DESKTOP = [ 1440, 900 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: DESKTOP

  # Every test in the run shares one browser window, so a test that shrinks it
  # shrinks the next one too. Each says what it needs; a subclass's setup runs
  # after this one and may say otherwise.
  setup { page.current_window.resize_to(*DESKTOP) }
end
