# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Milkdrop, the way Winamp drew it, rewritten for WebGL — and the presets people
# wrote for Milkdrop over twenty years, already compiled to JavaScript.
#
# Not preloaded: together they are the better part of a megabyte, and a listener
# who never opens the picture should never pay for it. The visualizer imports
# them the first time it is asked for, and the browser caches them from then on.
pin "butterchurn", preload: false # @2.6.7
pin "butterchurn-presets", preload: false # @2.4.7
