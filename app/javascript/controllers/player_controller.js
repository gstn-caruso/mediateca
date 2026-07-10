import { Controller } from "@hotwired/stimulus"

// Drives the one audio element in the layout. It lives outside the Turbo Drive
// body swap, so playback survives navigation.
export default class extends Controller {
  static targets = ["audio", "title", "subtitle", "cover"]

  play({ params: { src, title, subtitle, cover } }) {
    this.audioTarget.src = src
    this.audioTarget.play()

    this.titleTarget.textContent = title
    this.subtitleTarget.textContent = subtitle

    if (cover) {
      this.coverTarget.src = cover
      this.coverTarget.classList.remove("hidden")
    } else {
      this.coverTarget.classList.add("hidden")
    }
  }
}
