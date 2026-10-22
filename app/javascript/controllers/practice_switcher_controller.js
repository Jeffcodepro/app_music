import { Controller } from "@hotwired/stimulus"

// Native disclosure/link semantics remain available without JavaScript.
export default class extends Controller {
  static targets = ["summary"]

  connect() { this.sync() }

  sync() { this.summaryTarget.setAttribute("aria-expanded", String(this.element.open)) }

  close(restoreFocus = false) {
    this.element.open = false
    this.sync()
    if (restoreFocus) this.summaryTarget.focus()
  }

  escape(event) {
    if (!this.element.open) return
    event.preventDefault()
    event.stopPropagation()
    this.close(true)
  }

  outside(event) { if (this.element.open && !this.element.contains(event.target)) this.close() }
  navigate(event) { if (event.target.closest("a")) this.close() }
  beforeCache() { this.close() }
  confirm() { this.close(true) }
}
