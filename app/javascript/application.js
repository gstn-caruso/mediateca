// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// The worker that answers for a server that doesn't — see app/views/pwa.
//
// A browser only hands out workers in a secure context: over HTTPS, or on
// localhost. Served over plain http on a LAN, `navigator.serviceWorker` is not
// there at all, and Mediateca is the same app without it — a tab that works,
// rather than an app that fails to install. So this asks, and doesn't insist.
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/service-worker.js").catch(() => {
    // Nothing here is worth breaking the page over, and there is nobody at a
    // console in the kitchen to tell about it.
  })
}
