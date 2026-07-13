import { Controller } from "@hotwired/stimulus"

const OPEN = "is-open"

// The one <audio> in the app. The player owns it; this borrows its sound and
// watches whether it is running.
const AUDIO = "[data-player-target='audio']"

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
  wear(step, melt) {
    this.at = (this.at + step + this.names.length) % this.names.length
    this.visualizer.loadPreset(this.presets[this.name], melt)

    return this.name
  }

  render() {
    this.visualizer.render()
  }

  // Milkdrop does not own the canvas it draws on. It sizes its own framebuffers,
  // aims the viewport at them, and draws — and a canvas nobody has sized is
  // 300×150, which is simply what a canvas is. Left that way the picture came out
  // drawn through a letterbox and stretched over the rail.
  //
  // So the canvas is sized here. In DEVICE pixels, and Milkdrop is told the same
  // number with a ratio of one — because the number it is handed is the number it
  // aims its viewport at, while the ratio only decides how big its textures are.
  // Handed CSS pixels and a ratio of two, it sizes lovely retina textures and then
  // paints them into a quarter of the canvas: the picture sat in the bottom corner
  // of its own rail, on a retina screen and nowhere else. One number, one meaning.
  //
  // Sized twice with the same numbers, the assignment alone would blank the
  // buffer. Nothing to do is nothing to do — and saying so is worth something,
  // because whoever asked has a picture to put back.
  fit(width, height) {
    const across = Math.round(width * this.sharpness)
    const down = Math.round(height * this.sharpness)
    if (this.canvas.width === across && this.canvas.height === down) return false

    this.canvas.width = across
    this.canvas.height = down
    this.visualizer.setRendererSize(across, down)

    return true
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
    this.sizes?.disconnect()
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
    // Every time, not just the first. A browser will not let a page nobody has
    // touched make a sound, so a graph built on such a page is born asleep — and a
    // rail that remembered itself open is built on exactly such a page, before any
    // hand has gone near it. The graph was tapped once and never spoken to again,
    // and the music, which runs through it from the moment it is tapped, ran
    // through a sleeping graph into a silent house.
    //
    // This is the other end of that. The rail is raised again whenever the music
    // starts, and the music starts because a hand said so — which is the one thing
    // the browser was waiting to be told.
    this.tap()

    const show = await this.show()
    if (!this.live || !this.open) return

    this.fit()
    this.sizes ||= new ResizeObserver(() => this.fit())
    this.sizes.observe(this.canvasTarget)

    if (this.playing) this.paint(show)
    else this.still(show)
  }

  // Stopping is not asking for another frame. It is not stopping watching the
  // room: a rail that is open is still a rail that can be resized — thrown across
  // the whole screen, even — and a picture standing still has to be told, or it
  // stands there stretched. Watching is not drawing. Only the drawing stops here.
  hold() {
    cancelAnimationFrame(this.frame)
    this.frame = null
  }

  // A picture of the music, drawn while there is no music, is a picture of
  // nothing — and it churned away at sixty frames a second over a song that had
  // been paused for ten minutes. Stopping is simply not asking for another frame:
  // the last one drawn stays on the glass, which is what a paused thing looks
  // like. The music says when, because the music is the only one who knows.
  follow() {
    if (!this.open) return

    if (this.playing) this.raise()
    else this.hold()
  }

  get playing() {
    const audio = document.querySelector(AUDIO)

    return Boolean(audio && audio.src && !audio.paused)
  }

  paint(show) {
    const draw = () => {
      show.render()
      this.frame = requestAnimationFrame(draw)
    }

    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(draw)
  }

  // One frame, and then nothing. A rail opened over a song that is not playing
  // would otherwise be a black rectangle: there is a picture to show, it simply
  // is not moving.
  still(show) {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => {
      show.render()
      this.frame = null
    })
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

    // Before the visualiser is built, not after: it sizes its framebuffers and
    // aims the viewport at them the moment it is made, and a canvas that learns
    // its size afterwards has already been drawn on wrong once. Device pixels and
    // a ratio of one, for the reason spelled out over Show#fit.
    const across = Math.round((canvas.clientWidth || 1) * sharpness)
    const down = Math.round((canvas.clientHeight || 1) * sharpness)

    canvas.width = across
    canvas.height = down

    const visualizer = butterchurn.createVisualizer(context, canvas, {
      width: across, height: down, pixelRatio: 1
    })
    visualizer.connectAudio(source)

    const show = new Show(visualizer, presets.getPresets(), canvas, sharpness)
    canvas.show = show
    this.presetTarget.textContent = show.wear(0, 0)

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
    const audio = document.querySelector(AUDIO)

    audio.tap ||= (() => {
      const context = new AudioContext()
      const source = context.createMediaElementSource(audio)

      source.connect(context.destination)

      return { context, source }
    })()

    // A graph built before anybody pressed anything is born asleep, and a browser
    // wakes one only for a page a hand has been on. Asking anyway costs nothing and
    // is refused quietly; the hand will come, and this is asked again when it does.
    audio.tap.context.resume().catch(() => { /* not yet; there will be a hand */ })

    return audio.tap
  }

  // Milkdrop draws at the size it was last told, and a rail that has just been
  // thrown across the whole screen is not that size any more.
  //
  // Resizing a canvas empties it — that is what a canvas does when it is resized,
  // and while the music runs the next frame is a sixtieth of a second away and
  // nobody sees it happen. Stopped, no frame is coming: a paused picture thrown
  // full screen would have gone black on its way there. So it is drawn again by
  // hand, and only when there was actually a resize to undo.
  fit() {
    const { show, clientWidth: width, clientHeight: height } = this.canvasTarget
    if (!show || !width || !height) return

    const resized = show.fit(width, height)
    if (resized && !this.playing) this.still(show)
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

  // A preset melts into the next over two seconds, and a melt is frames. Stopped,
  // there are none coming — so a preset changed over a paused song is simply put
  // up, and the one frame that shows it is drawn by hand.
  wear(step) {
    const show = this.canvasTarget.show
    if (!show) return

    this.presetTarget.textContent = show.wear(step, this.playing ? MELT : 0)
    if (!this.playing) this.still(show)
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
