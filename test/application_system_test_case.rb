require "test_helper"

# The player controls are icon-only buttons: their accessible name is the
# aria-label. If a test can't find it, a screen reader can't either.
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ListeningInABrowser

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 900 ]
end
