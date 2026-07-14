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

const sum = (numbers) => numbers.reduce((all, number) => all + number, 0)

// Which of the room's numbers are this panel's.
const named = (panel) => `--${panel.dataset.panelNameValue}`

// What this panel takes of a room with no content in it. Read back off the room
// rather than kept anywhere here, exactly as the width is — and when nobody has
// ever divided an empty room, it is 1, which is the same nothing the CSS falls
// back to, and which divides the room into panels of a size.
const shareOf = (panel) =>
  parseFloat(getComputedStyle(document.documentElement).getPropertyValue(`${named(panel)}-share`)) || 1

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
      rate: this.rate,
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
  // With no content in the room there is nothing to settle *against*, and nothing
  // asking to be paid: the panels are the room, they are always exactly as wide as
  // it is, and a window narrowed takes the same slice out of all of them.
  settle() {
    if (this.folded || !this.adjustable) return

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

  // A rail's ceiling is the point at which it stops standing beside the content and
  // starts being it. With the content folded away it is not standing beside
  // anything, so there is nothing it can be too wide for — half an empty room is
  // half an empty room, and on this screen that is nowhere near 480 pixels.
  ends(panel) {
    if (panel === this.content) return [ CONTENT, Infinity ]

    return [ NARROWEST, this.folded ? Infinity : WIDEST ]
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
  //
  // Everything else is told to the room in whatever the room is counting in. With
  // a content standing in it that is pixels. With none, it is shares, and the hand
  // — which only ever moved in pixels — is turned back into them on the way out.
  // Only a drag can be here while the content is folded away; settle knows better
  // than to come, which is the whole reason there is a hand to ask for the rate.
  hold(panel, px) {
    if (panel === this.content) return

    if (this.folded) return this.tell(`${named(panel)}-share`, `${Math.round(px * this.hand.rate)}`)

    this.tell(named(panel), `${Math.round(px)}px`)
  }

  tell(number, held) {
    // Idempotent, and it has to be: this is what the observer calls, and a write
    // that changed nothing but fired the observer again would never stop.
    if (this.room.style.getPropertyValue(number) === held) return

    this.room.style.setProperty(number, held)
  }

  // A hand moves in pixels. A room with no content in it does not count in pixels —
  // it counts in shares — so this is the rate between the two.
  //
  // It holds still for the whole of a drag, and it has to, or the arithmetic would
  // be measured against a room that moved while it was being measured. It does hold
  // still: a trade hands one panel exactly what it takes from another, so neither
  // the shares standing in the room nor the pixels they are drawn in ever change.
  get rate() {
    if (!this.folded) return 1

    return sum(this.standing.map(shareOf)) / sum(this.standing.map(widthOf))
  }

  get standing() {
    return [ ...this.element.parentElement.children ]
      .filter((panel) => panel.classList.contains("panel") && panel.offsetParent)
  }

  get folded() {
    return !this.content.offsetParent
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

  // Written down in the currency it was let go of in. A panel let go of in a room
  // with no content in it has not been given a width — 950 pixels is not a width a
  // rail can hold, and the app would refuse it — it has been given a share, and
  // the two are kept apart. The width it stands at beside a page is still the width
  // it stands at beside a page, waiting for the page to come home.
  remember(panel) {
    if (panel === this.content) return

    fetch(`/panels/${panel.dataset.panelNameValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify(this.folded
        ? { share: Math.round(shareOf(panel)) }
        : { width: Math.round(widthOf(panel)) })
    })
  }
}
