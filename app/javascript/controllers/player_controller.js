import { Controller } from "@hotwired/stimulus"

const OFF = "off"
const ALL = "all"
const ONE = "one"

// Where the queue is written down so it can outlive a full reload. Named by the
// origin, so two apps on one host don't read each other's music.
const REMEMBERED = "mediateca:player"

// Drives the single <audio> element in the layout.
//
// Turbo Drive swaps the body on every navigation, so this controller is torn
// down and rebuilt constantly. The audio element is not: it lives inside
// #player, which is data-turbo-permanent. So the queue rides on the audio
// element rather than on the controller, and playback survives navigation.
export default class extends Controller {
  static values = { profile: String }

  static targets = [
    "audio", "title", "titleText", "idle", "subtitle", "subtitleText", "cover", "tail",
    "playIcon", "pauseIcon", "progress", "elapsed", "duration", "volume",
    "shuffle", "repeat", "repeatOne", "next", "queue", "queueEmpty", "queueToggle", "panel",
    "repeatBadge", "repeatBadgeText", "backdrop", "row"
  ]

  // Turbo builds the new body before it moves #player, the permanent element,
  // into it — so on navigation the controller connects to a body with no player
  // yet. Waiting to be told the audio arrived beats asking whether it has.
  audioTargetConnected() {
    this.restore()
    this.refreshIcons()
    if (this.hasVolumeTarget) this.paint(this.volumeTarget)
    this.tick()
    this.render()
  }

  // A tracklist arrives whenever you navigate, and the row that is playing may
  // be in it. Marking each row as it appears is not subject to that ordering.
  rowTargetConnected(row) {
    this.mark(row)
  }

  // A click on a track queues the whole tracklist it belongs to, so the album
  // keeps playing on its own — and keeps playing while you browse elsewhere.
  play({ params: { index } }) {
    this.queue = this.rowTargets.map((row) => ({ ...row.dataset }))
    this.order = this.shuffled ? this.shuffleAround(index) : this.queue.map((_, at) => at)
    this.cursor = this.order.indexOf(index)
    this.start()
  }

  // The big shuffle button on a record turns shuffle on and then plays it, the
  // way pressing shuffle in Spotify is a way of pressing play.
  playShuffled(event) {
    this.shuffled = true
    this.play(event)
  }

  // Jumping from the queue panel: the track is already queued, only the cursor
  // moves.
  jump({ params: { at } }) {
    this.cursor = at
    this.start()
  }

  toggle() {
    if (!this.audioTarget.src) return

    this.audioTarget.paused ? this.audioTarget.play() : this.audioTarget.pause()
  }

  next() {
    if (this.cursor + 1 < this.order.length) this.cursor += 1
    else if (this.repeating === ALL) this.cursor = 0
    else return

    this.start()
  }

  // The first press restarts the track; only a second one goes back. Every
  // music player does this, and it is the only reason `previous` is not `next`
  // with a minus sign.
  previous() {
    if (this.audioTarget.currentTime > 3) {
      this.audioTarget.currentTime = 0
      return
    }
    if (this.cursor <= 0) return

    this.cursor -= 1
    this.start()
  }

  // A track that ended on its own obeys repeat-one; a listener pressing next
  // means next.
  advance() {
    if (this.repeating === ONE) {
      this.audioTarget.currentTime = 0
      this.audioTarget.play()
      return
    }

    this.next()
  }

  // Whatever is playing keeps playing; the order of what comes after changes
  // under it. So the queue index has to be read before the order is redealt.
  toggleShuffle() {
    const playing = this.order[this.cursor]

    this.shuffled = !this.shuffled

    if (playing !== undefined) {
      this.order = this.shuffled ? this.shuffleAround(playing) : this.queue.map((_, at) => at)
      this.cursor = this.order.indexOf(playing)
    }

    this.render()
  }

  cycleRepeat() {
    this.repeating = { [OFF]: ALL, [ALL]: ONE, [ONE]: OFF }[this.repeating]
    this.render()
  }

  // The rail shows on desktop through `md:flex`; the standing `hidden` folds it
  // shut. Both the topbar and the player carry a toggle, so keep them in step.
  toggleQueue() {
    const open = this.panelTarget.classList.toggle("md:flex")

    this.queueToggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", String(open)))
  }

  scrub() {
    const { duration } = this.audioTarget
    if (!Number.isFinite(duration)) return

    this.audioTarget.currentTime = (this.progressTarget.value / 1000) * duration
  }

  changeVolume() {
    this.audioTarget.volume = this.volumeTarget.value / 100
    this.paint(this.volumeTarget)
  }

  tick() {
    const { currentTime, duration } = this.audioTarget

    this.elapsedTarget.textContent = this.clock(currentTime)
    this.durationTarget.textContent = Number.isFinite(duration) ? this.clock(duration) : "–:––"
    this.progressTarget.value = Number.isFinite(duration) && duration > 0 ? (currentTime / duration) * 1000 : 0
    this.paint(this.progressTarget)
    this.save()
  }

  // Paints the played portion of a slider bright and the rest dim, so the fill
  // reads the same in every engine instead of leaning on accent-color.
  paint(range) {
    const filled = (range.value / range.max) * 100
    range.style.background =
      `linear-gradient(to right, #fff ${filled}%, rgba(255, 255, 255, 0.2) ${filled}%)`
  }

  refreshIcons() {
    const playing = this.audioTarget.src && !this.audioTarget.paused

    this.playIconTarget.classList.toggle("hidden", Boolean(playing))
    this.pauseIconTarget.classList.toggle("hidden", !playing)
    this.save()
  }

  // --- State, which lives in the <audio> because the <audio> survives Turbo -

  get queue() { return this.audioTarget.queue ?? [] }
  set queue(tracks) { this.audioTarget.queue = tracks }

  get order() { return this.audioTarget.order ?? [] }
  set order(indexes) { this.audioTarget.order = indexes }

  get cursor() { return this.audioTarget.cursor ?? -1 }
  set cursor(at) { this.audioTarget.cursor = at }

  get shuffled() { return this.audioTarget.shuffled ?? false }
  set shuffled(on) { this.audioTarget.shuffled = on }

  get repeating() { return this.audioTarget.repeating ?? OFF }
  set repeating(mode) { this.audioTarget.repeating = mode }

  get current() { return this.queue[this.order[this.cursor]] }

  // Whether next has anywhere to go: another track ahead, or repeat-all to wrap
  // back to the top. Mirrors what next() actually does.
  get hasNext() {
    if (this.cursor + 1 < this.order.length) return true

    return this.repeating === ALL && this.order.length > 0
  }

  // --- Private ---------------------------------------------------------------

  start() {
    const track = this.current
    if (!track) return

    this.audioTarget.src = track.src
    this.audioTarget.play()
    this.remember(track)
    this.render()
  }

  // History is written when a track starts, not when its file is fetched:
  // preload asks for the file before anybody presses play, and every seek asks
  // for it again. Nothing waits on this — a lost play is not worth a stutter.
  remember({ trackId }) {
    if (!trackId) return

    fetch("/plays", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ track_id: trackId })
    })
  }

  // Whatever is playing stays where it is; everything else gets dealt again.
  shuffleAround(index) {
    const rest = this.queue.map((_, at) => at).filter((at) => at !== index)

    for (let at = rest.length - 1; at > 0; at--) {
      const swap = Math.floor(Math.random() * (at + 1))
      ;[rest[at], rest[swap]] = [rest[swap], rest[at]]
    }

    return [index, ...rest]
  }

  render() {
    this.renderNowPlaying()
    this.renderControls()
    this.renderTail()
    this.renderQueue()
    this.renderRows()
    this.save()
  }

  // The queue rides on the <audio>, which a full reload throws away. So it is
  // also written to storage, tagged with whose it is: a reload rebuilds a bare
  // <audio> and we put the queue back onto it, but only for the same listener —
  // leaving a profile still takes the music. A source and time set here; the
  // browser may still refuse to resume unasked, and then it waits for a press.
  save() {
    try {
      localStorage.setItem(REMEMBERED, JSON.stringify({
        profile: this.profileValue,
        queue: this.queue, order: this.order, cursor: this.cursor,
        shuffled: this.shuffled, repeating: this.repeating,
        src: this.audioTarget.src || "", time: this.audioTarget.currentTime || 0,
        paused: this.audioTarget.paused
      }))
    } catch { /* private windows and full disks just forget; the tab still plays */ }
  }

  // Only a brand-new <audio> is rebuilt: after a Turbo visit the element is the
  // same one, still carrying its queue, and must be left alone.
  restore() {
    if (this.audioTarget.queue !== undefined) return

    const saved = this.remembered()
    if (!saved || saved.profile !== this.profileValue || !saved.src) return

    this.queue = saved.queue
    this.order = saved.order
    this.cursor = saved.cursor
    this.shuffled = saved.shuffled
    this.repeating = saved.repeating

    this.audioTarget.src = saved.src
    this.audioTarget.addEventListener("loadedmetadata", () => { this.audioTarget.currentTime = saved.time }, { once: true })
    if (!saved.paused) this.audioTarget.play().catch(() => {})
  }

  remembered() {
    try {
      return JSON.parse(localStorage.getItem(REMEMBERED))
    } catch {
      return null
    }
  }

  renderNowPlaying() {
    const track = this.current

    this.idleTarget.hidden = Boolean(track)
    this.titleTarget.hidden = !track
    if (!track) {
      this.subtitleTextTarget.textContent = ""
      this.clearBackdrop()
      this.clearAccent()
      return
    }

    this.titleTextTarget.textContent = track.title
    this.titleTarget.href = track.album
    this.subtitleTextTarget.textContent = track.subtitle

    this.coverTarget.src = track.cover
    this.coverTarget.classList.remove("hidden")

    this.marquee(this.titleTarget, this.titleTextTarget)
    this.marquee(this.subtitleTarget, this.subtitleTextTarget)

    this.setBackdrop(track.cover)
    this.paintAccentFrom(track.cover)
  }

  // A title or artist too long for its lane scrolls, pausing at each end, and
  // sits still when it fits. The distance is measured after layout, and drives
  // both how far it travels and how long it takes — long titles don't race.
  marquee(lane, text) {
    lane.classList.remove("is-scrolling")
    lane.style.removeProperty("--marquee-shift")
    lane.style.removeProperty("--marquee-duration")

    requestAnimationFrame(() => {
      const overflow = text.scrollWidth - lane.clientWidth
      if (overflow <= 2) return

      lane.style.setProperty("--marquee-shift", `-${overflow}px`)
      lane.style.setProperty("--marquee-duration", `${Math.max(6, overflow / 25)}s`)
      lane.classList.add("is-scrolling")
    })
  }

  // The cover of what's playing washes the whole floor. Two layers cross-fade:
  // paint the next cover on the layer that's hidden, then trade their opacities.
  setBackdrop(cover) {
    if (!this.hasBackdropTarget || !cover) return

    const shown = this.backdropTargets.find((layer) => layer.classList.contains("opacity-100"))
    if (shown?.dataset.cover === cover) return

    const next = this.backdropTargets.find((layer) => layer !== shown)
    next.style.backgroundImage = `url("${cover}")`
    next.dataset.cover = cover
    next.classList.replace("opacity-0", "opacity-100")
    shown?.classList.replace("opacity-100", "opacity-0")
  }

  // Nobody playing, no wash: both layers fade back to the bare backdrop.
  clearBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTargets.forEach((layer) => {
      layer.classList.replace("opacity-100", "opacity-0")
      delete layer.dataset.cover
    })
  }

  // --- The accent, taken from the record --------------------------------------
  //
  // The cover doesn't only wash the floor: its dominant color becomes the whole
  // app's accent. Overriding the theme's --color-accent on <html> retints every
  // bg-accent / text-accent / accent glow at once — the Play button, the playing
  // row, the equalizer, the glass edges and the ambient corner light all take on
  // the record's own hue. <html> survives Turbo, so the accent rides across
  // navigation; covers are same-origin, so the canvas can be read.
  paintAccentFrom(cover) {
    if (!cover || cover === this.accentCover) return
    this.accentCover = cover

    const img = new Image()
    img.addEventListener("load", () => {
      try {
        const [hue, saturation, lightness] = this.dominant(img)
        // Warm the cover's hue toward orange, so the accent — and the text it
        // tints — reads "medio anaranjada" rather than any raw sleeve colour.
        const h = this.warm(hue)
        // Pin it to a legible band: vivid enough to read as an accent, held
        // between light-enough to glow on the dark panels and dark-enough that
        // the flipped-to-fit label still contrasts.
        const s = Math.min(0.92, Math.max(0.55, saturation))
        const l = Math.min(0.62, Math.max(0.50, lightness))
        const rgb = this.hslToRgb(h, s, l)
        const bright = this.hslToRgb(h, s, Math.min(0.72, l + 0.09))
        // White reads on most accents, but not on a pale yellow one; let the
        // accent's own luminance decide whether its label goes white or near-black.
        const onAccent = this.luminance(rgb) > 0.42 ? "#0a0a0a" : "#ffffff"
        this.setAccent(rgb, bright, onAccent)
      } catch { /* tainted or unreadable: keep the standing accent */ }
    }, { once: true })
    img.addEventListener("error", () => { this.accentCover = null }, { once: true })
    img.src = cover
  }

  // Retint the app to a color. The bare-var tints (glass/gel/ambient) get the
  // accent at the alphas their glows expect, since the compiler won't let those
  // read the accent through a color-mix — see the :root defaults in the CSS.
  setAccent(rgb, bright, onAccent) {
    const [r, g, b] = rgb.map(Math.round)
    const triplet = `${r}, ${g}, ${b}`
    const root = document.documentElement.style

    root.setProperty("--color-accent", this.hex(rgb))
    root.setProperty("--color-accent-bright", this.hex(bright))
    root.setProperty("--color-on-accent", onAccent)
    root.setProperty("--glass-tint", `rgba(${triplet}, 0.16)`)
    root.setProperty("--glass-tint-deep", `rgba(${triplet}, 0.12)`)
    root.setProperty("--gel-glow", `rgba(${triplet}, 0.55)`)
    root.setProperty("--ambient-tint", `rgba(${triplet}, 0.14)`)
  }

  // Back to the standing Apple-red theme defaults when nothing is playing.
  clearAccent() {
    this.accentCover = null
    const root = document.documentElement.style
    for (const name of [
      "--color-accent", "--color-accent-bright", "--color-on-accent",
      "--glass-tint", "--glass-tint-deep", "--gel-glow", "--ambient-tint"
    ]) root.removeProperty(name)
  }

  // Pull a hue toward orange (30°) along the shortest arc, so a warm sleeve
  // reads clearly orange while a genuinely cool one is only nudged, not turned
  // into a lie. The 0.6 weight and the ±45° cap are what keep it "medio".
  warm(h) {
    const arc = ((30 - h + 540) % 360) - 180

    return (h + Math.max(-45, Math.min(45, arc * 0.6)) + 360) % 360
  }

  // The cover's dominant hue: sample it small, bucket every vivid, mid-toned
  // pixel by hue weighted by how saturated it is, and return the heaviest
  // bucket's average as [h, s, l]. Greys and near-black/white sit the vote out,
  // so a mostly-grey sleeve is decided by its one splash of color.
  dominant(img) {
    const size = 36
    const canvas = document.createElement("canvas")
    canvas.width = canvas.height = size
    const ctx = canvas.getContext("2d", { willReadFrequently: true })
    ctx.drawImage(img, 0, 0, size, size)
    const { data } = ctx.getImageData(0, 0, size, size)

    const buckets = Array.from({ length: 12 }, () => ({ r: 0, g: 0, b: 0, w: 0 }))
    for (let i = 0; i < data.length; i += 4) {
      if (data[i + 3] < 200) continue
      const r = data[i], g = data[i + 1], b = data[i + 2]
      const [h, s, l] = this.rgbToHsl(r, g, b)
      if (s < 0.2 || l < 0.12 || l > 0.9) continue

      const bucket = buckets[Math.floor(h / 30) % 12]
      bucket.r += r * s; bucket.g += g * s; bucket.b += b * s; bucket.w += s
    }

    const winner = buckets.reduce((best, bucket) => (bucket.w > best.w ? bucket : best), buckets[0])
    if (winner.w === 0) return this.rgbToHsl(250, 45, 72) // a silent, grey sleeve stays red
    return this.rgbToHsl(winner.r / winner.w, winner.g / winner.w, winner.b / winner.w)
  }

  rgbToHsl(r, g, b) {
    r /= 255; g /= 255; b /= 255
    const max = Math.max(r, g, b), min = Math.min(r, g, b)
    const l = (max + min) / 2
    const d = max - min
    if (d === 0) return [0, 0, l]

    const s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    let h
    switch (max) {
      case r: h = (g - b) / d + (g < b ? 6 : 0); break
      case g: h = (b - r) / d + 2; break
      default: h = (r - g) / d + 4
    }
    return [h * 60, s, l]
  }

  hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360
    const c = (1 - Math.abs(2 * l - 1)) * s
    const x = c * (1 - Math.abs((h / 60) % 2 - 1))
    const m = l - c / 2
    const [r, g, b] =
      h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] :
      h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x]
    return [(r + m) * 255, (g + m) * 255, (b + m) * 255]
  }

  // WCAG relative luminance, to decide what color of text can sit on the accent.
  luminance([r, g, b]) {
    const channel = (v) => {
      v /= 255
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4
    }
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
  }

  hex([r, g, b]) {
    const pair = (v) => Math.round(v).toString(16).padStart(2, "0")
    return `#${pair(r)}${pair(g)}${pair(b)}`
  }

  // Shuffle and repeat moved off the mini-player; when their buttons aren't on
  // the page there is nothing to keep in sync.
  renderControls() {
    if (!this.hasShuffleTarget) return

    this.shuffleTarget.setAttribute("aria-pressed", String(this.shuffled))
    this.repeatTarget.setAttribute("aria-pressed", String(this.repeating !== OFF))
    this.repeatOneTarget.hidden = this.repeating !== ONE
  }

  // The end of the queue, said out loud: next has nowhere to go, so dim it, and
  // if a track is actually playing it out (not looping on one), name the end.
  renderTail() {
    this.nextTarget.disabled = !this.hasNext
    this.tailTarget.hidden = !(this.current && !this.hasNext && this.repeating !== ONE)
  }

  renderQueue() {
    const base = this.cursor + 1
    const upcoming = this.order.slice(base).map((at, offset) => this.queueRow(at, base + offset))

    const children = []
    if (this.current) children.push(this.queueSection("Now Playing"), this.nowPlayingRow(this.current))
    if (upcoming.length) children.push(this.queueSection("Next Up"), ...upcoming)
    this.queueTarget.replaceChildren(...children)

    const empty = upcoming.length === 0
    this.queueEmptyTarget.hidden = !empty
    // Repeat-all never runs out: the queue loops back rather than ending.
    this.queueEmptyTarget.textContent =
      empty && this.repeating === ALL && this.order.length > 0 ? "Repeats from the top." : "Nothing up next."

    this.repeatBadgeTarget.hidden = this.repeating === OFF
    this.repeatBadgeTextTarget.textContent = this.repeating === ONE ? "Repeat One" : "Repeat"
  }

  // A quiet header inside the list to tell "Now Playing" from "Next Up".
  queueSection(label) {
    const li = document.createElement("li")
    li.className = "select-none px-1.5 pb-1 pt-3 text-[11px] font-semibold uppercase tracking-wider text-neutral-500 first:pt-1"
    li.textContent = label
    return li
  }

  // What's on now: art, title and artist, lit in accent behind an equalizer. It
  // doesn't move and can't be dropped — it isn't up next, it's playing.
  nowPlayingRow(track) {
    const item = document.createElement("li")
    item.className = "flex items-center gap-2.5 rounded-lg bg-white/5 p-1.5 ring-1 ring-inset ring-white/10"

    const meter = document.createElement("span")
    meter.className = "shrink-0 pr-0.5 text-accent"
    meter.innerHTML = '<svg class="size-4" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M1 14V9h2v5H1Zm4.5 0V2h2v12h-2ZM10 14V6h2v8h-2Zm4.5 0v-4h1.5v4h-1.5Z"/></svg>'

    item.append(this.queueArt(track), this.queueText(track, "text-accent"), meter)
    return item
  }

  // A queue row: art, title and artist, click to jump to it. The whole row is a
  // drag handle for reordering; the × to drop it surfaces on hover. position is
  // its index into the play order, so drag and remove speak the same
  // coordinates.
  queueRow(at, position) {
    const track = this.queue[at]

    const item = document.createElement("li")
    item.className = "group flex items-center gap-1 rounded-lg pr-1 transition hover:bg-white/10"
    item.draggable = true
    item.dataset.pos = position
    item.dataset.action = "dragstart->player#dragStart dragover->player#dragOver drop->player#drop dragend->player#dragEnd"

    const jump = document.createElement("button")
    jump.type = "button"
    jump.setAttribute("aria-label", track.title)
    jump.className = "flex min-w-0 flex-1 cursor-grab items-center gap-2.5 rounded-lg p-1.5 text-left active:cursor-grabbing"
    jump.dataset.action = "player#jump"
    jump.dataset.playerAtParam = position
    jump.append(this.queueArt(track), this.queueText(track))

    const remove = document.createElement("button")
    remove.type = "button"
    remove.setAttribute("aria-label", `Remove ${track.title} from the queue`)
    remove.className = "shrink-0 rounded-full p-1.5 text-neutral-500 transition hover:bg-white/10 hover:text-white group-hover:text-neutral-300"
    remove.dataset.action = "player#removeFromQueue"
    remove.dataset.playerAtParam = position
    remove.innerHTML = '<svg class="size-3.5" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M4.28 3.22a.75.75 0 0 0-1.06 1.06L6.94 8l-3.72 3.72a.75.75 0 1 0 1.06 1.06L8 9.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L9.06 8l3.72-3.72a.75.75 0 0 0-1.06-1.06L8 6.94 4.28 3.22Z"/></svg>'

    item.append(jump, remove)
    return item
  }

  // The small album thumbnail every queue row wears.
  queueArt(track) {
    const art = document.createElement("img")
    art.src = track.cover
    art.alt = ""
    art.className = "size-10 shrink-0 rounded object-cover shadow ring-1 ring-white/10"
    return art
  }

  // A title over a dimmer artist, each clipped to one line.
  queueText(track, titleColor = "text-neutral-100") {
    const text = document.createElement("span")
    text.className = "min-w-0 flex-1"

    const title = document.createElement("span")
    title.className = `block truncate text-sm font-medium ${titleColor}`
    title.textContent = track.title

    const artist = document.createElement("span")
    artist.className = "block truncate text-xs text-neutral-400"
    artist.textContent = track.subtitle

    text.append(title, artist)
    return text
  }

  // --- The queue, rearranged ---------------------------------------------------

  dragStart(event) {
    this.dragFrom = Number(event.currentTarget.dataset.pos)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-40")
  }

  // Something can only be dropped where dropping was allowed.
  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()
    this.moveInQueue(this.dragFrom, Number(event.currentTarget.dataset.pos))
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-40")
  }

  // Only what hasn't played yet moves, so the cursor and everything behind it
  // stay put while the tail is redealt.
  moveInQueue(from, to) {
    if (Number.isNaN(from) || Number.isNaN(to) || from === to) return

    const base = this.cursor + 1
    const tail = this.order.slice(base)
    const [moved] = tail.splice(from - base, 1)
    tail.splice(to - base, 0, moved)

    this.order = [...this.order.slice(0, base), ...tail]
    this.render()
  }

  removeFromQueue({ params: { at } }) {
    const base = this.cursor + 1
    const tail = this.order.slice(base)
    tail.splice(at - base, 1)

    this.order = [...this.order.slice(0, base), ...tail]
    this.render()
  }

  // The album page can be any album, or none. Only the row that is playing gets
  // marked, and only if it is on screen.
  renderRows() {
    this.rowTargets.forEach((row) => this.mark(row))
  }

  mark(row) {
    const playing = this.hasAudioTarget && this.current?.src

    row.setAttribute("aria-current", String(Boolean(playing) && row.dataset.src === playing))
  }

  clock(seconds) {
    if (!Number.isFinite(seconds)) return "–:––"

    const minutes = Math.floor(seconds / 60)
    const rest = Math.floor(seconds % 60)

    return `${minutes}:${String(rest).padStart(2, "0")}`
  }
}
