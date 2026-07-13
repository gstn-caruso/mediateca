import { Controller } from "@hotwired/stimulus"

const OPEN = "is-open"

// How long one preset takes to melt into the next. Milkdrop never cut between
// them and neither does this: two seconds of the old picture becoming the new one.
const MELT = 2.0

// Retina draws four pixels where a screen draws one, and Milkdrop is drawing
// every one of them sixty times a second. Two is where it stops being worth it.
const SHARPNESS = 2

// Butterchurn and its presets are both webpack UMD bundles, and the two disagree
// about where they left their exports.
const api = (bundle) => bundle?.default ?? bundle

// What is on the wall: the visualiser itself, every preset ever written for
// Milkdrop, and which one of them is up.
class Show {
  constructor(visualizer, presets, canvas, sharpness) {
    this.visualizer = visualizer
    this.presets = presets
    this.canvas = canvas
    this.sharpness = sharpness
    this.names = Object.keys(presets)
    this.at = Math.floor(Math.random() * this.names.length)
  }

  get name() {
    return this.names[this.at]
  }

  // Along the wall, and round the end of it: the presets are a ring, because
  // there is no reason for the last one to be a dead end.
  wear(step) {
    this.at = (this.at + step + this.names.length) % this.names.length
    this.visualizer.loadPreset(this.presets[this.name], step === 0 ? 0 : MELT)

    return this.name
  }

  render() {
    this.visualizer.render()
  }

  // Milkdrop does not own the canvas it draws on. It sizes its own framebuffers,
  // points the viewport at them, and draws — and if nobody ever told the canvas
  // how big it is, a canvas is 300×150 by definition, and the picture is drawn
  // through a letterbox and stretched over the rail. So the backing store is set
  // here, and set to exactly what Milkdrop is about to draw: it works in CSS
  // pixels and multiplies by the ratio itself, so this multiplies by the same one.
  //
  // Sized twice with the same numbers, the assignment alone would blank the
  // buffer. Nothing to do is nothing to do.
  fit(width, height) {
    const across = Math.round(width * this.sharpness)
    const down = Math.round(height * this.sharpness)
    if (this.canvas.width === across && this.canvas.height === down) return

    this.canvas.width = across
    this.canvas.height = down
    this.visualizer.setRendererSize(width, height)
  }
}

// Milkdrop, in a rail.
//
// Turbo Drive tears this controller down and builds it again on every visit. The
// rail it sits on does not go: it is permanent, like the <audio>. So a WebGL
// context and a megabyte of presets — neither of which is a thing to rebuild
// because somebody clicked on a record — are made once and kept on the canvas.
export default class extends Controller {
  static targets = [ "canvas", "preset", "fullscreen" ]

  connect() {
    this.live = true
    this.settle()
  }

  disconnect() {
    this.live = false
    this.hold()
  }

  // Draw while the rail is open, and not a frame while it is shut. The player
  // owns the rail and says when it opens; a full load opens it from storage
  // instead, and either can happen before this controller exists. So this reads
  // the rail rather than trusting the news that reached it.
  settle() {
    if (this.open) this.raise()
    else this.hold()
  }

  get open() {
    return this.element.classList.contains(OPEN)
  }

  // Nothing is instant here: the first raise waits on the better part of a
  // megabyte. A rail can be shut again in that time, and a visit can tear this
  // controller down and stand a new one up on the very same rail — and then both
  // of them come back to this line. The one that has been torn down has already
  // had its loop cancelled, and would quietly start a second one that nothing is
  // left holding the handle of: two loops drawing one picture, forever.
  async raise() {
    const show = await this.show()
    if (!this.live || !this.open) return

    this.fit()
    this.sizes ||= new ResizeObserver(() => this.fit())
    this.sizes.observe(this.canvasTarget)

    this.paint(show)
  }

  hold() {
    cancelAnimationFrame(this.frame)
    this.frame = null
    this.sizes?.disconnect()
  }

  paint(show) {
    const draw = () => {
      show.render()
      this.frame = requestAnimationFrame(draw)
    }

    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(draw)
  }

  // The one Show there is. Opening the rail twice while the libraries are still
  // on their way must not raise two of them, so what is kept on the canvas is the
  // promise, not the thing.
  show() {
    this.canvasTarget.rising ||= this.raiseShow(this.canvasTarget)

    return this.canvasTarget.rising
  }

  async raiseShow(canvas) {
    const [ butterchurn, presets ] = await Promise.all([
      import("butterchurn").then(() => api(window.butterchurn)),
      import("butterchurn-presets").then(() => api(window.butterchurnPresets))
    ])

    const { context, source } = this.tap()
    const sharpness = Math.min(window.devicePixelRatio || 1, SHARPNESS)
    const width = canvas.clientWidth || 1
    const height = canvas.clientHeight || 1

    // Before the visualiser is built, not after: it sizes its framebuffers and
    // aims the viewport at them the moment it is made, and a canvas that learns
    // its size afterwards has already been drawn on wrong once.
    canvas.width = Math.round(width * sharpness)
    canvas.height = Math.round(height * sharpness)

    const visualizer = butterchurn.createVisualizer(context, canvas, {
      width, height, pixelRatio: sharpness
    })
    visualizer.connectAudio(source)

    const show = new Show(visualizer, presets.getPresets(), canvas, sharpness)
    canvas.show = show
    this.wear(0)

    return show
  }

  // To draw the music the picture has to hear it, and the only way to hear an
  // <audio> is to stand in the middle of it: the element's sound is taken off it
  // and handed to the graph. Which leaves the graph owing the speakers their
  // sound back — miss that one line and the picture comes up beautifully over a
  // silent house.
  //
  // Taking it is a one-way door, too: an element can be tapped once and never
  // again. So the tap is made on first use and kept on the <audio>, which is the
  // one thing in this app that outlives everything.
  tap() {
    const audio = document.querySelector("[data-player-target='audio']")

    audio.tap ||= (() => {
      const context = new AudioContext()
      const source = context.createMediaElementSource(audio)

      source.connect(context.destination)

      return { context, source }
    })()

    // A graph built before anybody pressed anything is born asleep. Opening the
    // rail is a press, and this is where it is spent.
    audio.tap.context.resume()

    return audio.tap
  }

  // Milkdrop draws at the size it was last told, and a rail that has just been
  // thrown across the whole screen is not that size any more.
  fit() {
    const { show, clientWidth: width, clientHeight: height } = this.canvasTarget
    if (!show || !width || !height) return

    show.fit(width, height)
  }

  // The arrows walk the presets — but they are the search box's arrows first, and
  // a caret has to be able to move through a word somebody is typing.
  hotkey(event) {
    const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key]
    if (!step || !this.open || event.metaKey || event.ctrlKey || event.altKey) return

    const { target } = event
    if (target.isContentEditable || [ "INPUT", "TEXTAREA", "SELECT" ].includes(target.tagName)) return

    event.preventDefault()
    this.wear(step)
  }

  wear(step) {
    const show = this.canvasTarget.show
    if (!show) return

    this.presetTarget.textContent = show.wear(step)
  }

  // Full screen is where Milkdrop was always going. The rail asks for it whole,
  // so what fills the screen is the picture and not a canvas with a window's
  // worth of glass still stuck to the top of it.
  fullscreen() {
    if (document.fullscreenElement === this.element) document.exitFullscreen()
    else this.element.requestFullscreen()
  }

  // Escape leaves full screen without going through the button, so what the
  // button says about itself is read back off the document rather than toggled.
  refit() {
    this.fullscreenTarget.setAttribute("aria-pressed", String(document.fullscreenElement === this.element))
    this.fit()
  }
}
