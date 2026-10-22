import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["area", "listening", "repetitions", "room", "roomStatus", "emptyRooms"]
  connect() { this.update() }
  update() {
    if (!this.hasAreaTarget) return
    const audible = this.areaTarget.value !== "leitura"
    this.listeningTarget.hidden = !audible
    this.repetitionsTarget.disabled = !audible
  }

  async finishRoom(event) {
    event.preventDefault()
    const form = event.currentTarget
    if (form.dataset.pending) return
    form.dataset.pending = "true"
    const button = form.querySelector('button[type="submit"]')
    button.disabled = true
    this.roomStatusTarget.textContent = "Encerrando a sala…"
    try {
      const response = await fetch(form.action, { method: "POST", credentials: "same-origin",
        headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }, body: new FormData(form) })
      if (!response.ok) throw new Error("Room changed")
      form.closest('[data-arena-setup-target="room"]').remove()
      this.emptyRoomsTarget.hidden = this.roomTargets.length > 0
      this.roomStatusTarget.textContent = `${form.dataset.roomTitle} foi encerrada. Seus resultados foram preservados e a configuração da nova sala continua abaixo.`
      const next = this.roomTargets[0]?.querySelector("a") || this.element?.querySelector('input[name="title"]')
      next?.focus({ preventScroll: true })
    } catch {
      this.roomStatusTarget.textContent = "Não foi possível encerrar. A sala pode ter mudado; abra a sala para conferir ou atualize a página."
    } finally {
      delete form.dataset.pending
      button.disabled = false
    }
  }
}
