import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "label"]
  static values = { storageKey: String }

  connect() {
    const collapsed = localStorage.getItem(this.storageKeyValue) === "true"
    this.setCollapsed(collapsed)
  }

  toggle() {
    this.setCollapsed(!this.isCollapsed())
  }

  isCollapsed() {
    return this.element.classList.contains("is-sidebar-collapsed")
  }

  setCollapsed(collapsed) {
    this.element.classList.toggle("is-sidebar-collapsed", collapsed)
    if (this.hasStorageKeyValue) {
      localStorage.setItem(this.storageKeyValue, String(collapsed))
    }
  }
}
