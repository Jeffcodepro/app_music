import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "toggle", "workspace", "toggleSlot"]
  static values = { storageKey: String, drawerOnly: Boolean, mobileBreakpoint: { type: Number, default: 767 } }

  connect() {
    this.desktop = window.matchMedia("(min-width: 1200px)")
    this.mobile = window.matchMedia(`(max-width: ${this.mobileBreakpointValue}px)`)
    try { this.element.classList.toggle("is-sidebar-collapsed", localStorage.getItem(this.storageKeyValue) === "true") } catch (_) {}
    this.viewportChanged = () => { this.close(); this.update() }
    this.desktop.addEventListener("change", this.viewportChanged)
    this.mobile.addEventListener("change", this.viewportChanged)
    this.update()
  }

  disconnect() {
    this.close(false)
    this.desktop.removeEventListener("change", this.viewportChanged)
    this.mobile.removeEventListener("change", this.viewportChanged)
  }

  toggle() {
    if (this.desktop.matches && !this.drawerOnlyValue) {
      this.element.classList.toggle("is-sidebar-collapsed")
      try { localStorage.setItem(this.storageKeyValue, String(this.element.classList.contains("is-sidebar-collapsed"))) } catch (_) {}
      this.update()
    } else if (this.open) {
      this.close()
    } else {
      this.returnFocus = document.activeElement
      this.previousOverflow = document.body.style.overflow
      this.open = true
      // Keep the very same toggle reachable while the workspace is inert.
      this.togglePlaceholder = document.createComment("menu-toggle")
      this.toggleTarget.before(this.togglePlaceholder)
      this.toggleLabel = this.toggleTarget.getAttribute("aria-label")
      this.toggleSlotTarget.append(this.toggleTarget)
      this.toggleTarget.setAttribute("aria-label", "Fechar menu")
      this.element.classList.add("is-drawer-open")
      document.body.style.overflow = "hidden"
      this.workspaceTarget.inert = true
      this.update()
      this.toggleTarget.focus()
    }
  }

  close(restoreFocus = true) {
    const wasOpen = this.open
    this.open = false
    this.element.classList.remove("is-drawer-open")
    this.workspaceTarget.inert = false
    if (this.togglePlaceholder) {
      this.togglePlaceholder.replaceWith(this.toggleTarget)
      this.toggleTarget.setAttribute("aria-label", this.toggleLabel)
      this.togglePlaceholder = null
    }
    if (wasOpen) document.body.style.overflow = this.previousOverflow || ""
    this.update()
    if (wasOpen && restoreFocus !== false) {
      if (this.returnFocus?.isConnected && this.returnFocus.getClientRects().length) this.returnFocus.focus()
      else this.workspaceTarget.querySelector("a[href], button")?.focus()
    }
  }

  navigate(event) {
    if (event.target.closest("a")) this.close()
  }

  beforeCache() { this.close(false) }

  keydown(event) {
    if (!this.open) return
    if (event.key === "Escape") { event.preventDefault(); this.close(); return }
    if (event.key !== "Tab") return
    const items = [...this.sidebarTarget.querySelectorAll("a[href], button, select, summary")].filter(el => !el.disabled && el.getClientRects().length)
    const first = items[0], last = items[items.length - 1]
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus() }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus() }
  }

  update() {
    const expanded = this.desktop?.matches && !this.drawerOnlyValue ? !this.element.classList.contains("is-sidebar-collapsed") : !!this.open
    this.toggleTargets.forEach(button => button.setAttribute("aria-expanded", String(expanded)))
    this.sidebarTarget.inert = !!this.mobile?.matches && !this.open
    if (this.open) {
      this.sidebarTarget.setAttribute("role", "dialog")
      this.sidebarTarget.setAttribute("aria-modal", "true")
    } else {
      this.sidebarTarget.removeAttribute("role")
      this.sidebarTarget.removeAttribute("aria-modal")
    }
  }
}
