import { Controller } from "@hotwired/stimulus"

// Drives the single <audio> element in the layout.
//
// Turbo Drive swaps the body on every navigation, so this controller is torn
// down and rebuilt constantly. The audio element is not: it lives inside
// #player, which is data-turbo-permanent. So the queue rides on the audio
// element rather than on the controller, and playback survives navigation.
export default class extends Controller {
  static targets = [
    "audio", "title", "subtitle", "cover",
    "playIcon", "pauseIcon", "progress", "elapsed", "duration", "volume"
  ]

  connect() {
    this.refreshIcons()
    this.tick()
  }

  // A click on a track queues the whole tracklist it belongs to, so the album
  // keeps playing on its own — and keeps playing while you browse elsewhere.
  play({ params: { index } }) {
    this.queue = Array.from(document.querySelectorAll("[data-player-track]")).map((row) => ({ ...row.dataset }))
    this.position = index
    this.#load()
  }

  toggle() {
    if (!this.audioTarget.src) return

    this.audioTarget.paused ? this.audioTarget.play() : this.audioTarget.pause()
  }

  next() {
    if (this.position + 1 >= this.queue.length) return

    this.position += 1
    this.#load()
  }

  // The first press restarts the track; only a second one goes back. Every
  // music player does this, and it is the only reason `previous` is not `next`
  // with a minus sign.
  previous() {
    if (this.audioTarget.currentTime > 3) {
      this.audioTarget.currentTime = 0
      return
    }
    if (this.position <= 0) return

    this.position -= 1
    this.#load()
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

    this.elapsedTarget.textContent = this.#clock(currentTime)
    this.durationTarget.textContent = Number.isFinite(duration) ? this.#clock(duration) : "–:––"
    this.progressTarget.value = Number.isFinite(duration) && duration > 0 ? (currentTime / duration) * 1000 : 0
  }

  refreshIcons() {
    const playing = this.audioTarget.src && !this.audioTarget.paused

    this.playIconTarget.classList.toggle("hidden", playing)
    this.pauseIconTarget.classList.toggle("hidden", !playing)
  }

  get queue() {
    return this.audioTarget.queue ?? []
  }

  set queue(tracks) {
    this.audioTarget.queue = tracks
  }

  get position() {
    return this.audioTarget.position ?? -1
  }

  set position(index) {
    this.audioTarget.position = index
  }

  #load() {
    const track = this.queue[this.position]
    if (!track) return

    this.audioTarget.src = track.src
    this.audioTarget.play()

    this.titleTarget.textContent = track.title
    this.subtitleTarget.textContent = track.subtitle

    this.coverTarget.src = track.cover
    this.coverTarget.classList.remove("hidden")
  }

  #clock(seconds) {
    if (!Number.isFinite(seconds)) return "–:––"

    const minutes = Math.floor(seconds / 60)
    const rest = Math.floor(seconds % 60)

    return `${minutes}:${String(rest).padStart(2, "0")}`
  }
}
