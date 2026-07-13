import { Controller } from "@hotwired/stimulus"

// Where the player was left. #player is data-turbo-permanent, so it carries its
// own place through a visit without being told twice — this is for the cold
// load, which builds it again out of HTML the server wrote knowing nothing about
// anybody's hand.
const REMEMBERED = "mediateca:player-spot"

// How near the bottom edge of the room the pointer has to come before the player
// gives way to a bar.
//
// It is the pointer that is measured and not the player, and that is the whole
// of the design. The pill already rests a touch above the bottom, so a player
// that docked when its own foot reached the floor would dock on a nudge — which
// is not what anybody means by dragging it to the bottom. So the room holds the
// player back at the floor, the hand goes on pushing past where the player can
// follow, and that push — travel the thing itself cannot make — is the ask. It
// is how a window is thrown at the edge of a screen everywhere else.
const FLOOR = 32

// Placed by a hand, standing on the floor, or in a hand right now. Untouched, it
// wears none of these and simply rests where the layout put it.
const FLOATING = "is-floating"
const DOCKED = "is-docked"
const DRAGGING = "is-dragging"

// Between one edge and the other — and the far edge first, for a room too small
// to hold the player at all.
const within = (value, most) => Math.min(Math.max(value, 0), Math.max(most, 0))

// The player floats where it is put, and docks when it is pushed into the floor.
//
// Nothing about where it is lives in this controller. Turbo tears this down and
// builds it again on every visit while #player itself, being permanent, never
// moves — so the element is asked where it is rather than told, exactly as the
// queue is kept on the <audio> rather than on the player controller. The classes
// say which of the three it is; the coordinates ride in custom properties, the
// way the lit pill under the library's tabs rides in --tab. The CSS does the
// placing. This only decides.
export default class extends Controller {
  connect() {
    const spot = this.remembered()
    if (!spot) return

    if (spot.docked) this.dock()
    else this.floatAt(spot.x, spot.y)
  }

  // Anything on the player that is not a control is a handle: the cover, the
  // words, the room around them. The transport is pressed and the scrubber is
  // dragged for a living — a hand on either of those came for the music, not for
  // the player, and a press that flung the whole thing across the room would be
  // the last time anybody pressed anything.
  grab(event) {
    if (event.target.closest("button, a, input")) return

    const player = this.element.getBoundingClientRect()
    this.hand = { x: event.clientX - player.left, y: event.clientY - player.top }

    this.element.setPointerCapture(event.pointerId)
    this.element.classList.add(DRAGGING)

    // Or the drag is spent selecting the name of the song under the hand.
    event.preventDefault()
  }

  drag(event) {
    if (!this.hand) return

    const room = this.room()
    if (room.bottom - event.clientY <= FLOOR) return this.dock()

    this.floatAt(event.clientX - this.hand.x - room.left, event.clientY - this.hand.y - room.top)
  }

  // A press that moved nothing is a press, and it writes nothing down: the
  // player is only somewhere on purpose once a hand has actually put it there.
  drop(event) {
    if (!this.hand) return

    this.hand = null
    this.element.classList.remove(DRAGGING)
    this.element.releasePointerCapture(event.pointerId)

    if (this.docked) this.remember({ docked: true })
    else if (this.floating) this.remember(this.placed())
  }

  // A window shrinking under a player left near its edge would take the player
  // over the side with it, and a player over the side is gone for good: there is
  // no scrolling to it, and it is the only transport there is. So the room holds
  // it, and goes on holding it. Docked, there is nothing to hold: a bar is as
  // wide as the row, whatever the row becomes.
  settle() {
    if (!this.floating) return

    const room = this.room()
    const player = this.element.getBoundingClientRect()

    this.floatAt(player.left - room.left, player.top - room.top)
  }

  // Measured with the bar taken off first, so what is read is the size of the
  // pill it is about to be again, rather than the size of the row it was.
  floatAt(x, y) {
    this.element.classList.remove(DOCKED)

    const room = this.room()
    const player = this.element.getBoundingClientRect()

    this.element.style.setProperty("--x", `${within(x, room.width - player.width)}px`)
    this.element.style.setProperty("--y", `${within(y, room.height - player.height)}px`)
    this.element.classList.add(FLOATING)
  }

  dock() {
    this.element.classList.remove(FLOATING)
    this.element.classList.add(DOCKED)
  }

  get docked() {
    return this.element.classList.contains(DOCKED)
  }

  get floating() {
    return this.element.classList.contains(FLOATING)
  }

  // The room: the pane the player is placed against, which is the whole app,
  // edge to edge.
  room() {
    return this.element.offsetParent.getBoundingClientRect()
  }

  placed() {
    const style = this.element.style

    return { x: parseFloat(style.getPropertyValue("--x")), y: parseFloat(style.getPropertyValue("--y")) }
  }

  remember(spot) {
    try {
      localStorage.setItem(REMEMBERED, JSON.stringify(spot))
    } catch { /* a private window just forgets where it was left */ }
  }

  remembered() {
    try {
      return JSON.parse(localStorage.getItem(REMEMBERED))
    } catch {
      return null
    }
  }
}
