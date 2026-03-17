import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 10000 }
  }

  connect() {
    this.closed = false
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    if (this.timer) clearTimeout(this.timer)
  }

  close(event) {
    event.preventDefault()
    this.dismiss()
  }

  dismiss() {
    if (this.closed) return
    this.closed = true
    this.element.classList.add("is-leaving")
    setTimeout(() => this.element.remove(), 220)
  }
}
