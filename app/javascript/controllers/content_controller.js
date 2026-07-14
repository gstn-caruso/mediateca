import { Controller } from "@hotwired/stimulus"

// How wide a listener keeps a panel hangs off the listener, because the kitchen
// tablet and the laptop are the same person and want the same library. Whether
// the content is folded away is not that kind of thing: it is about the screen
// in front of you now — the laptop with room for everything has no business
// being told the tablet went looking for more of the queue. So the browser keeps
// this one, the way it keeps which rails are open.
const REMEMBERED = "mediateca:content"

// The library folds by having `md:flex` taken off it, and that was enough: a rail
// that is gone hands its room back to the content, and flexbox needs to be told
// nothing. There is no content to hand the content's room back to. Folding it is
// three things at once — it goes, the panels left standing take the room, and the
// seams between them stop being seams — and the stylesheet is the only place all
// three can be said together. This says which way it was left, and no more.
const FOLDED = "is-folded"

export default class extends Controller {
  static targets = [ "panel", "toggle" ]

  // Turbo builds the content fresh on every visit — it is the page. It comes back
  // unfolded every time, so this is not a restore-once: it is the answer to the
  // question the new page is asking, and it is asked again on each one.
  connect() {
    this.panelTarget.classList.toggle(FOLDED, localStorage.getItem(REMEMBERED) === "folded")
    this.announce()
  }

  toggle() {
    this.panelTarget.classList.toggle(FOLDED)
    this.announce()

    try {
      localStorage.setItem(REMEMBERED, this.folded ? "folded" : "open")
    } catch { /* a private window just forgets which way it was left */ }
  }

  // The button is the only way back: folded, there is nothing left on screen to
  // click. So it has to say which way it is pointing to anybody who cannot see it.
  announce() {
    this.toggleTarget.setAttribute("aria-expanded", String(!this.folded))
  }

  get folded() {
    return this.panelTarget.classList.contains(FOLDED)
  }
}
