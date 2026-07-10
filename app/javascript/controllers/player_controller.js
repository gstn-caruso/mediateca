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
    "audio", "title", "titleText", "idle", "subtitle", "subtitleText", "quality", "cover", "tail",
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
      this.qualityTarget.hidden = true
      this.clearBackdrop()
      return
    }

    this.titleTextTarget.textContent = track.title
    this.titleTarget.href = track.album
    this.subtitleTextTarget.textContent = track.subtitle

    // The badge only shows for a file we measured; a blank one says nothing.
    this.qualityTarget.hidden = !track.quality
    this.qualityTarget.textContent = track.quality || ""
    this.qualityTarget.title = track.qualityDetail || ""

    this.coverTarget.src = track.cover
    this.coverTarget.classList.remove("hidden")

    this.marquee(this.titleTarget, this.titleTextTarget)
    this.marquee(this.subtitleTarget, this.subtitleTextTarget)

    this.setBackdrop(track.cover)
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
    const rows = this.order.slice(base).map((at, offset) => this.queueRow(at, base + offset))

    this.queueTarget.replaceChildren(...rows)

    const empty = rows.length === 0
    this.queueEmptyTarget.hidden = !empty
    // Repeat-all never runs out: the queue loops back rather than ending.
    this.queueEmptyTarget.textContent =
      empty && this.repeating === ALL && this.order.length > 0 ? "Repeats from the top." : "Nothing up next."

    this.repeatBadgeTarget.hidden = this.repeating === OFF
    this.repeatBadgeTextTarget.textContent = this.repeating === ONE ? "Repeat One" : "Repeat"
  }

  // A queue row is a drag handle, the track (click to jump), and a way to drop
  // it. position is its index into the play order, so drag and remove speak the
  // same coordinates.
  queueRow(at, position) {
    const track = this.queue[at]

    const item = document.createElement("li")
    item.className = "group flex cursor-grab items-center gap-1 rounded-lg pl-1 transition hover:bg-white/10 active:cursor-grabbing"
    item.draggable = true
    item.dataset.pos = position
    item.dataset.action = "dragstart->player#dragStart dragover->player#dragOver drop->player#drop dragend->player#dragEnd"

    const grip = document.createElement("span")
    grip.className = "shrink-0 text-neutral-600 transition group-hover:text-neutral-400"
    grip.innerHTML = '<svg class="size-4" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M6 3a1 1 0 1 1-2 0 1 1 0 0 1 2 0Zm0 5a1 1 0 1 1-2 0 1 1 0 0 1 2 0Zm-1 6a1 1 0 1 0 0-2 1 1 0 0 0 0 2Zm7-11a1 1 0 1 1-2 0 1 1 0 0 1 2 0Zm-1 6a1 1 0 1 0 0-2 1 1 0 0 0 0 2Zm1 4a1 1 0 1 1-2 0 1 1 0 0 1 2 0Z"/></svg>'

    const button = document.createElement("button")
    button.type = "button"
    button.textContent = track.title
    button.className = "min-w-0 flex-1 truncate py-2 text-left text-sm text-neutral-300 transition group-hover:text-white"
    button.dataset.action = "player#jump"
    button.dataset.playerAtParam = position

    const remove = document.createElement("button")
    remove.type = "button"
    remove.setAttribute("aria-label", `Remove ${track.title} from the queue`)
    remove.className = "shrink-0 rounded-full p-1.5 text-neutral-500 transition hover:bg-white/10 hover:text-white"
    remove.dataset.action = "player#removeFromQueue"
    remove.dataset.playerAtParam = position
    remove.innerHTML = '<svg class="size-3.5" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M4.28 3.22a.75.75 0 0 0-1.06 1.06L6.94 8l-3.72 3.72a.75.75 0 1 0 1.06 1.06L8 9.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L9.06 8l3.72-3.72a.75.75 0 0 0-1.06-1.06L8 6.94 4.28 3.22Z"/></svg>'

    item.append(grip, button, remove)
    return item
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
