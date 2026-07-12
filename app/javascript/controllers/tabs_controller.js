import { Controller } from "@hotwired/stimulus"

// One library, three ways to look at it: the artists, the records, the lists.
//
// Which way it is turned is not something the page can carry. The rail is
// re-rendered on every Turbo visit — its active row moves with you — so, like
// the rail's own folded-shut state, the turn is written down and read back on
// connect rather than riding along in the DOM.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { showing: String, remember: String }

  connect() {
    const remembered = this.remembered()
    if (this.names.includes(remembered)) this.showingValue = remembered

    this.paint()
  }

  show({ params: { name } }) {
    this.showingValue = name
    this.paint()
    this.write(name)
  }

  // A tablist is steered with the arrows, and this one is icons: whoever is on
  // the keyboard has no labels to read and every reason to expect them to work.
  step(event) {
    const by = { ArrowLeft: -1, ArrowRight: 1 }[event.key]
    if (!by) return

    event.preventDefault()
    const at = this.names.indexOf(this.showingValue)
    const next = this.tabTargets[(at + by + this.names.length) % this.names.length]

    next.focus()
    next.click()
  }

  // The pill under the icons is one chip wide and slides by whole chips, so the
  // index is all the CSS needs to know — it inherits down to the track.
  paint() {
    this.tabTargets.forEach((tab, index) => {
      const on = tab.dataset.tabsNameParam === this.showingValue

      tab.setAttribute("aria-selected", on)
      // Tab lands on the control, not on each of its icons; the arrows move within.
      tab.tabIndex = on ? 0 : -1
      if (on) this.element.style.setProperty("--tab", index)
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tabsName !== this.showingValue
    })
  }

  get names() {
    return this.tabTargets.map((tab) => tab.dataset.tabsNameParam)
  }

  remembered() {
    try {
      return localStorage.getItem(this.rememberValue)
    } catch {
      return null
    }
  }

  write(name) {
    try {
      localStorage.setItem(this.rememberValue, name)
    } catch { /* a private window just forgets which way it was left */ }
  }
}
