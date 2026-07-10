import { Controller } from "@hotwired/stimulus"

// Collapses the library rail on the left. Unlike the player, the rail is
// re-rendered on every Turbo visit — its active row moves with you — so it
// cannot just ride along. The choice is written down and read back on connect.
const REMEMBERED = "mediateca:library"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    if (localStorage.getItem(REMEMBERED) === "collapsed") this.panelTarget.classList.remove("md:flex")
  }

  // The rail shows on desktop through `md:flex`; taking that away lets the
  // standing `hidden` fold it shut without touching the phone, where it never
  // showed to begin with. Flexbox hands the space back to the content.
  toggle() {
    const open = this.panelTarget.classList.toggle("md:flex")

    try {
      localStorage.setItem(REMEMBERED, open ? "open" : "collapsed")
    } catch { /* a private window just forgets which way it was left */ }
  }
}
