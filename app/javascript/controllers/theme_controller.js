import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "choice", "toggle"]
  static values = { fixed: String }

  connect() {
    this.media = window.matchMedia("(prefers-color-scheme: dark)")
    this.refresh = () => this.apply()
    this.storageChanged = (event) => {
      if (!event || event.key === "app_music_theme" || event.key === null) this.apply(this.preference(true))
    }
    this.media.addEventListener("change", this.refresh)
    window.addEventListener("storage", this.storageChanged)
    this.apply(this.preference(true))
  }

  disconnect() {
    this.media.removeEventListener("change", this.refresh)
    window.removeEventListener("storage", this.storageChanged)
  }

  selectTargetConnected(select) { select.value = this.preference() }
  choiceTargetConnected(choice) { choice.setAttribute("aria-pressed", String(choice.value === this.preference())) }
  choose(event) { this.change({ target: event.currentTarget }) }

  preference(fromStorage = false) {
    const current = document.documentElement.dataset.themePreference
    if (!fromStorage && ["light", "dark", "system"].includes(current)) return current
    try {
      const value = localStorage.getItem("app_music_theme")
      return ["light", "dark", "system"].includes(value) ? value : "system"
    } catch (_) { return ["light", "dark", "system"].includes(current) ? current : "system" }
  }

  change(event) {
    const value = event.target.value
    if (!["light", "dark", "system"].includes(value)) return
    try { localStorage.setItem("app_music_theme", value) } catch (_) {}
    this.apply(value)
  }

  apply(preference = this.preference()) {
    if (this.fixedValue === "light") {
      document.documentElement.dataset.theme = "light"
      document.documentElement.dataset.bsTheme = "light"
      document.documentElement.style.colorScheme = "light"
      return
    }
    if (typeof preference !== "string") preference = this.preference()
    const resolved = preference === "system" ? (this.media.matches ? "dark" : "light") : preference
    document.documentElement.dataset.themePreference = preference
    document.documentElement.dataset.theme = resolved
    document.documentElement.dataset.bsTheme = resolved
    document.documentElement.style.colorScheme = resolved
    this.selectTargets.forEach(select => { select.value = preference })
    this.choiceTargets.forEach(choice => { choice.setAttribute("aria-pressed", String(choice.value === preference)) })
    const label = { light: "Claro", dark: "Escuro", system: "Sistema" }[preference]
    this.toggleTargets.forEach(toggle => { toggle.setAttribute("aria-label", `Tema da interface: ${label}`) })
  }
}
