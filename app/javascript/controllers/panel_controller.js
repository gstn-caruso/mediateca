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

const widthOf = (panel) => panel.getBoundingClientRect().width

// Which of the room's four numbers is this panel's.
const named = (panel) => `--${panel.dataset.panelNameValue}`

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

  // A hand takes a seam, and a seam is between things: this panel, and everything
  // standing behind it that will give way. All of them are measured now, once — a
  // drag is told from where it began, not from wherever the last frame left it.
  grab(event) {
    const givers = this.givers

    this.hand = {
      x: event.clientX,
      givers,
      was: new Map([ this.element, ...givers ].map((panel) => [ panel, widthOf(panel) ]))
    }

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

    this.move(this.edgeValue === "left" ? -travelled : travelled)
  }

  // A press that moved nothing is a press, and it writes nothing down. What did
  // move is written down — all of it. The panel that gave was never touched by the
  // hand, and it is a width its listener now keeps all the same: they moved it,
  // they just moved it from the other end of the seam.
  drop(event) {
    if (!this.hand) return

    const { was } = this.hand
    this.hand = null

    this.element.classList.remove("is-resizing")
    event.target.releasePointerCapture(event.pointerId)

    was.forEach((before, panel) => {
      if (Math.round(widthOf(panel)) !== Math.round(before)) this.remember(panel)
    })
  }

  // The room closing in on a panel somebody left wide — a window narrowed, a rail
  // opened beside it — holds it back, and goes on holding it. It writes nothing
  // down: the room taking room back is not somebody changing their mind, and on a
  // screen that can hold it again, it is theirs again.
  settle() {
    if (!this.adjustable) return

    this.hold(this.element, within(this.width, NARROWEST, this.most))
  }

  // The seam moves, and moving a seam is a trade: what this panel takes, the room
  // behind it gives — the panel across the seam first, then the one behind that,
  // and the content last of all.
  //
  // It used to be the content that paid, and only the content: wherever in the
  // room the seam was and whichever side was pulled, the content was the leftovers
  // and the leftovers are what every drag came out of. Two rails standing side by
  // side had a seam between them that neither of them ever felt.
  //
  // What nobody behind the seam can pay, this panel does not take — and that is
  // the whole of why the room stays exactly as full as it was. The arithmetic is a
  // trade, so there is never anything left over to lose.
  move(asked) {
    const { was, givers } = this.hand

    const wanted = this.step(this.element, was.get(this.element), asked)

    let owed = wanted
    const given = new Map()

    for (const giver of givers) {
      const paid = owed === 0 ? 0 : this.step(giver, was.get(giver), -owed)

      given.set(giver, paid)
      owed += paid
    }

    this.hold(this.element, was.get(this.element) + wanted - owed)
    given.forEach((paid, giver) => this.hold(giver, was.get(giver) + paid))
  }

  // How far a panel goes when it is asked to go this far: as far as it can, and
  // then it stops being what it is. A rail under its floor cannot say what it is
  // for; a rail over its ceiling has stopped standing beside the content and
  // started being it; and a page under CONTENT is a page nobody can read.
  step(panel, from, asked) {
    const [ least, most ] = this.ends(panel)

    return within(from + asked, least, most) - from
  }

  ends(panel) {
    return panel === this.content ? [ CONTENT, Infinity ] : [ NARROWEST, WIDEST ]
  }

  // Everything standing behind this panel's edge, nearest first: the panels that
  // give way when it takes room, in the order the room gives it up. A shut rail is
  // not standing anywhere, so it is stepped over.
  //
  // The content is the end of it. A rail leans on the rail beside it and, when
  // that one is spent, on the page — but the page is where this side of the room
  // stops. Nothing a hand does to the right of the content should be felt on its
  // left.
  get givers() {
    const behind = this.edgeValue === "left" ? "previousElementSibling" : "nextElementSibling"
    const standing = []

    for (let panel = this.element[behind]; panel; panel = panel[behind]) {
      if (!panel.offsetParent) continue

      standing.push(panel)

      if (panel === this.content) break
    }

    return standing
  }

  // The content is written down nowhere. It is what the panels have not taken, and
  // it becomes that the moment they take it — so a room that has been told the
  // panels has already been told the content.
  hold(panel, px) {
    if (panel === this.content) return

    const held = `${Math.round(px)}px`

    // Idempotent, and it has to be: this is what the observer calls, and a write
    // that changed nothing but fired the observer again would never stop.
    if (this.room.style.getPropertyValue(named(panel)) === held) return

    this.room.style.setProperty(named(panel), held)
  }

  // How far this one can go when the *room* is what moved: to its own far end, or
  // until the content is down to the least room a page can be read in — whichever
  // it meets first.
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
    return widthOf(this.content) - CONTENT
  }

  get width() {
    return widthOf(this.element)
  }

  get content() {
    return document.getElementById("content")
  }

  get room() {
    return document.documentElement
  }

  // Shut, or on a phone. Either way there is no edge standing between two things,
  // so there is nothing to take hold of — and a shut rail measures zero, which is
  // not a width anybody chose and must never be written down as one. The grip is
  // the honest answer to both: it is there exactly when the panel is a thing you
  // can widen.
  get adjustable() {
    return this.gripTarget.offsetParent !== null
  }

  remember(panel) {
    if (panel === this.content) return

    fetch(`/panels/${panel.dataset.panelNameValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ width: Math.round(widthOf(panel)) })
    })
  }
}
