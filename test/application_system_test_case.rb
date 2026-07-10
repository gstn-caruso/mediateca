require "test_helper"

# Los controles del player son botones de solo ícono: su nombre accesible es el
# aria-label. Si un test no lo encuentra, un lector de pantalla tampoco.
Capybara.enable_aria_label = true

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 900 ]
end
