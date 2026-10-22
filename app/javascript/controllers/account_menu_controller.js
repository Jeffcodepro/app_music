import PracticeSwitcherController from "./practice_switcher_controller"

export default class extends PracticeSwitcherController {
  static targets = ["summary", "panel"]

  connect() {
    super.connect()
    this.sidebar = this.element.closest('.app-sidebar')
    this.onSidebarScroll = () => this.viewportChanged()
    this.sidebar?.addEventListener('scroll', this.onSidebarScroll)
  }

  disconnect() { this.sidebar?.removeEventListener('scroll', this.onSidebarScroll) }

  sync() {
    super.sync()
    if (!this.element.open) return
    const rect = this.summaryTarget.getBoundingClientRect()
    const width = Math.min(380, window.innerWidth - 32)
    const above = rect.top - 16, below = window.innerHeight - rect.bottom - 16
    const upwards = above >= 200 || above >= below
    Object.assign(this.panelTarget.style, {
      width: `${width}px`, left: `${Math.max(16, Math.min(rect.left, window.innerWidth - width - 16))}px`,
      maxHeight: `${Math.max(96, (upwards ? above : below) - 8)}px`,
      top: upwards ? 'auto' : `${rect.bottom + 8}px`, bottom: upwards ? `${window.innerHeight - rect.top + 8}px` : 'auto'
    })
  }

  viewportChanged() {
    const restore = this.panelTarget.contains(document.activeElement) && !this.summaryTarget.closest('[inert]') && this.summaryTarget.getBoundingClientRect().width > 0
    this.close(restore)
  }
}
