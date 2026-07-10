import { Controller } from "@hotwired/stimulus"

// Collapses the library rail on the left. Unlike the player, the rail is
// re-rendered on every Turbo visit — its active row moves with you — so it
// cannot just ride along. The choice is written down and read back on connect.
const REMEMBERED = "mediateca:library"

export default class extends Controller {
  static targets = ["panel", "content"]

  connect() {
    if (localStorage.getItem(REMEMBERED) === "collapsed") {
      this.panelTarget.classList.remove("md:flex")
      this.inset(false)
    }
  }

  // The rail shows on desktop through `md:flex`; taking that away lets the
  // standing `hidden` fold it shut without touching the phone, where it never
  // showed to begin with. The content reclaims the space it leaves.
  toggle() {
    const open = this.panelTarget.classList.toggle("md:flex")
    this.inset(open)

    try {
      localStorage.setItem(REMEMBERED, open ? "open" : "collapsed")
    } catch { /* a private window just forgets which way it was left */ }
  }

  inset(open) {
    this.contentTarget.classList.toggle("md:pl-80", open)
    this.contentTarget.classList.toggle("md:pl-6", !open)
  }
}
