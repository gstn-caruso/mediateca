import { Controller } from "@hotwired/stimulus"

// The width every panel was nailed to before a hand could move them, and still
// the width of one nobody has ever touched.
const BORN = 288

// The ends of the rope. The Panel model holds the same two numbers, and it has to:
// this end holds the hand, and that end holds the request — and a request is not a
// hand. Anybody on the LAN can send this app any number they like.
const NARROWEST = 240
const WIDEST = 480

// The least room a page can be read in. A hand that could go on widening the rails
// until there was nothing left to widen them beside would be a hand holding a
// library with no music in it.
const CONTENT = 360

const within = (value, least, most) => Math.min(Math.max(value, least), Math.max(least, most))

// A panel is as wide as the hand that last held its edge left it.
//
// Nothing about how wide it is lives in this controller — and nothing about it
// lives on the panel, either. Turbo rebuilds the library rail on every visit: it
// is the one panel that cannot be permanent, because it has to know which page you
// are standing on. A width kept on that element would be gone the moment you
// clicked an artist, and reading it back off the server would be a PATCH nobody
// waited for racing the GET of whatever was clicked next.
//
// So the width is kept on the room — <html>, the one element a visit does not
// replace. The hand writes it there, the CSS reads it back, and every page drawn
// afterwards is already wearing it. This only decides.
export default class extends Controller {
  static values = { name: String, edge: String }
  static targets = [ "grip" ]

  // What a panel has to know is how much room the content has left, and it would
  // rather watch that than be told. The room changes for more reasons than a
  // window being dragged — a rail opening beside it takes as much room as a window
  // losing an inch, and the player docking takes a row — and none of those are
  // this panel's business to know about. The content is.
  connect() {
    this.watching = new ResizeObserver(() => this.settle())
    this.watching.observe(this.content)
  }

  disconnect() {
    this.watching.disconnect()
  }

  grab(event) {
    this.hand = { x: event.clientX, width: this.width }

    event.target.setPointerCapture(event.pointerId)
    this.element.classList.add("is-resizing")

    // Or the drag is spent selecting the rail it is dragging.
    event.preventDefault()
  }

  // The library is opened by its right edge and the other three by their left, so
  // the same hand moving the same way means opposite things on opposite sides of
  // the room. The edge is what says which.
  drag(event) {
    if (!this.hand) return

    const travelled = event.clientX - this.hand.x

    this.widen(this.hand.width + (this.edgeValue === "left" ? -travelled : travelled))
  }

  // A press that moved nothing is a press, and it writes nothing down.
  drop(event) {
    if (!this.hand) return

    const was = this.hand.width
    this.hand = null

    this.element.classList.remove("is-resizing")
    event.target.releasePointerCapture(event.pointerId)

    if (Math.round(this.width) !== Math.round(was)) this.remember()
  }

  // The room closing in on a panel somebody left wide — a window narrowed, a rail
  // opened beside it — holds it back, and goes on holding it. It writes nothing
  // down: the room taking room back is not somebody changing their mind, and on a
  // screen that can hold it again, it is theirs again.
  settle() {
    if (this.adjustable) this.widen(this.width)
  }

  widen(wanted) {
    const held = `${Math.round(within(wanted, NARROWEST, this.most))}px`

    // Idempotent, and it has to be: this is what the observer calls, and a write
    // that changed nothing but fired the observer again would never stop.
    if (this.room.style.getPropertyValue(this.mine) === held) return

    this.room.style.setProperty(this.mine, held)
  }

  // How far this one can go: to its own far end, or until the content is down to
  // the least room a page can be read in — whichever it meets first.
  //
  // But never back past the width it was born at. On a tablet with a rail open the
  // content is *already* under its floor, and has been since long before any of
  // this — so a room allowed to take back whatever it liked would answer that by
  // shrinking rails nobody had touched. The room may take back what a hand added.
  // It may not take back what the app shipped.
  get most() {
    return Math.max(BORN, Math.min(WIDEST, this.width + this.spare))
  }

  get spare() {
    return this.content.getBoundingClientRect().width - CONTENT
  }

  get width() {
    return this.element.getBoundingClientRect().width
  }

  get content() {
    return document.getElementById("content")
  }

  get room() {
    return document.documentElement
  }

  // Which of the room's four numbers is this panel's.
  get mine() {
    return `--${this.nameValue}`
  }

  // Shut, or on a phone. Either way there is no edge standing between two things,
  // so there is nothing to take hold of — and a shut rail measures zero, which is
  // not a width anybody chose and must never be written down as one. The grip is
  // the honest answer to both: it is there exactly when the panel is a thing you
  // can widen.
  get adjustable() {
    return this.gripTarget.offsetParent !== null
  }

  remember() {
    fetch(`/panels/${this.nameValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ width: Math.round(this.width) })
    })
  }
}
