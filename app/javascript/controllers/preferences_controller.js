import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "panel"]

  connect() {
    if (!this.hasPanelTarget) return
    try {
      this.panelTarget.open = sessionStorage.getItem(this.panelKey()) === "open"
    } catch (_) { /* Disclosure remains usable when browser storage is unavailable. */ }
  }

  rememberExpanded() {
    if (!this.hasPanelTarget) return
    try {
      sessionStorage.setItem(this.panelKey(), this.panelTarget.open ? "open" : "closed")
    } catch (_) { /* Native details needs no storage to operate. */ }
  }

  panelKey() {
    return `app-music-playground-settings:${this.panelTarget.dataset.preferencesKey}`
  }

  submit() {
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }
}
