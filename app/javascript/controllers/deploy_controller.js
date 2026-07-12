import { Controller } from "@hotwired/stimulus"

// Catching up with a deploy you could not have heard.
//
// A deploy says so out loud — see app/models/deploy.rb — and a tab that is
// listening morphs onto it at once. The trouble is that a tab is almost never
// listening at that moment: the container holding its socket is the very one
// being replaced, so the socket dies a second or two before the new build gets
// to speak, and the tab spends the announcement reconnecting. Nothing replays
// it. Said into an empty room, and the tabs stay on last week's build.
//
// So coming back is the question worth asking. The build that served this page
// is written on it; when the socket returns, we ask which build is answering
// now, and if it is another one the page refreshes onto it — morphing, exactly
// as the announcement would have made it do, and just as gently: the <audio> is
// permanent, and a morph steps around it.
export default class extends Controller {
  static values = { build: String }

  connect() {
    this.cable = document.querySelector("turbo-cable-stream-source")
    if (!this.cable) return

    this.listening = this.cable.hasAttribute("connected")
    this.watch = new MutationObserver(() => this.cableChanged())
    this.watch.observe(this.cable, { attributes: true, attributeFilter: [ "connected" ] })
  }

  disconnect() {
    this.watch?.disconnect()
  }

  cableChanged() {
    const listening = this.cable.hasAttribute("connected")
    const cameBack = listening && !this.listening
    this.listening = listening

    if (cameBack) this.catchUp()
  }

  // A socket drops for all sorts of reasons that are not a deploy — the wifi, a
  // laptop shutting its lid — so coming back is a question, not an answer. The
  // page is only refreshed if the app underneath it actually changed.
  async catchUp() {
    try {
      const answering = (await (await fetch("/build")).text()).trim()

      if (answering && answering !== this.buildValue) {
        window.Turbo.renderStreamMessage('<turbo-stream action="refresh"></turbo-stream>')
      }
    } catch {
      // Still finding its way back. The next reconnection asks again.
    }
  }
}
