import { Controller } from "@hotwired/stimulus"

const OFF = "off"
const ALL = "all"
const ONE = "one"

// Drives the single <audio> element in the layout.
//
// Turbo Drive swaps the body on every navigation, so this controller is torn
// down and rebuilt constantly. The audio element is not: it lives inside
// #player, which is data-turbo-permanent. So the queue rides on the audio
// element rather than on the controller, and playback survives navigation.
export default class extends Controller {
  static targets = [
    "audio", "title", "idle", "subtitle", "cover",
    "playIcon", "pauseIcon", "progress", "elapsed", "duration", "volume",
    "shuffle", "repeat", "repeatOne", "queue", "queueEmpty", "queueToggle", "panel",
    "row"
  ]

  // Turbo builds the new body before it moves #player, the permanent element,
  // into it — so on navigation the controller connects to a body with no player
  // yet. Waiting to be told the audio arrived beats asking whether it has.
  audioTargetConnected() {
    this.refreshIcons()
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

  toggleQueue() {
    this.panelTarget.hidden = !this.panelTarget.hidden
    this.queueToggleTarget.setAttribute("aria-expanded", String(!this.panelTarget.hidden))
  }

  scrub() {
    const { duration } = this.audioTarget
    if (!Number.isFinite(duration)) return

    this.audioTarget.currentTime = (this.progressTarget.value / 1000) * duration
  }

  changeVolume() {
    this.audioTarget.volume = this.volumeTarget.value / 100
  }

  tick() {
    const { currentTime, duration } = this.audioTarget

    this.elapsedTarget.textContent = this.clock(currentTime)
    this.durationTarget.textContent = Number.isFinite(duration) ? this.clock(duration) : "–:––"
    this.progressTarget.value = Number.isFinite(duration) && duration > 0 ? (currentTime / duration) * 1000 : 0
  }

  refreshIcons() {
    const playing = this.audioTarget.src && !this.audioTarget.paused

    this.playIconTarget.classList.toggle("hidden", Boolean(playing))
    this.pauseIconTarget.classList.toggle("hidden", !playing)
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
    this.renderQueue()
    this.renderRows()
  }

  renderNowPlaying() {
    const track = this.current

    this.idleTarget.hidden = Boolean(track)
    this.titleTarget.hidden = !track
    if (!track) return

    this.titleTarget.textContent = track.title
    this.titleTarget.href = track.album
    this.subtitleTarget.textContent = track.subtitle

    this.coverTarget.src = track.cover
    this.coverTarget.classList.remove("hidden")
  }

  renderControls() {
    this.shuffleTarget.setAttribute("aria-pressed", String(this.shuffled))
    this.repeatTarget.setAttribute("aria-pressed", String(this.repeating !== OFF))
    this.repeatOneTarget.hidden = this.repeating !== ONE
  }

  renderQueue() {
    const upcoming = this.order.slice(this.cursor + 1)

    this.queueTarget.replaceChildren(...upcoming.map((at, offset) => this.queueRow(at, this.cursor + 1 + offset)))
    this.queueEmptyTarget.hidden = upcoming.length > 0
  }

  queueRow(at, position) {
    const track = this.queue[at]
    const item = document.createElement("li")
    const button = document.createElement("button")

    button.type = "button"
    button.textContent = track.title
    button.className = "w-full truncate rounded px-3 py-2 text-left text-sm text-neutral-300 transition hover:bg-white/10 hover:text-white"
    button.dataset.action = "player#jump"
    button.dataset.playerAtParam = position

    item.append(button)
    return item
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
