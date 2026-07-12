import { Controller } from "@hotwired/stimulus"

// A confirmation is something you show and then stop showing. This one takes its
// own leave: it says what happened, waits long enough to be read, and goes —
// giving back the button that summoned it.
export default class extends Controller {
  static values = { after: { type: Number, default: 2200 } }

  connect() {
    this.leaving = setTimeout(() => this.element.remove(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.leaving)
  }
}
