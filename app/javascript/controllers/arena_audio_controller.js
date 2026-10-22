import { Controller } from "@hotwired/stimulus"
import { activateArenaAudio } from "audio/arena_listening"

// Existing players own soundfont/fallback/cancellation. This gateway only
// coordinates the protected listening receipt; it never submits an answer.
export default class extends Controller {
  static targets = ["trigger", "status", "cue"]
  static values = { player: String, startUrl: String, completeUrl: String, generation: Number, policy: String, slots: Array, serverNow: String, repetitions: Number }
  connect() {
    this.abort = new AbortController(); this.busy = false
    this.attempted = new Set()
    this.finished = new Set()
    this.clockOffset = Date.parse(this.serverNowValue) - Date.now()
    if (this.policyValue === "sequence-v1") {
      this.sequenceTimer = setInterval(() => this.tickSequence(), 100)
      this.tickSequence()
    }
  }
  disconnect() { this.abort?.abort(); clearInterval(this.sequenceTimer) }
  async enable() {
    try { await activateArenaAudio(); this.tickSequence() }
    catch { this.statusTarget.textContent = "Ative o áudio neste navegador para ouvir. Nenhuma resposta registrada." }
  }
  showCue(text) { if (this.hasCueTarget && this.cueTarget.textContent !== text) this.cueTarget.textContent = text }
  tickSequence() {
    if (this.abort.signal.aborted) return
    const enabled = window.__appMusicArenaAudioEnabled
    this.triggerTarget.hidden = Boolean(enabled)
    if (!enabled) { this.triggerTarget.textContent = "Ativar áudio"; return }
    const now = Date.now() + this.clockOffset
    const slots = this.slotsValue || []
    const slot = slots.find(item => now >= Date.parse(item.cue_at) && now < Date.parse(item.cutoff_at))
    if (!slot) {
      if (slots.length && now < Date.parse(slots[0].cue_at)) this.showCue("Prepare os ouvidos…")
      return
    }
    if (slot.completed) { this.showCue("Escuta já concluída. Aguardando a próxima etapa…"); return }
    if (this.finished.has(slot.listen)) return
    if (this.hasCueTarget) {
      const ordinal = ["Primeira", "Segunda", "Terceira", "Quarta", "Quinta"][slot.listen - 1]
      this.showCue(`${ordinal} escuta · ${slot.listen} de ${this.repetitionsValue}`)
      this.element.dataset.listen = slot.listen
    }
    if (!this.busy && now >= Date.parse(slot.play_at) && !this.attempted.has(slot.listen)) {
      if (this.application && !this.application.getControllerForElementAndIdentifier(this.element, this.playerValue)) return
      this.attempted.add(slot.listen)
      void this.play(slot.listen)
    }
  }
  async post(url, body) {
    const response = await fetch(url, { method: "POST", credentials: "same-origin", signal: this.abort.signal,
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content }, body: JSON.stringify(body) })
    if (!response.ok) throw new Error("Listening unavailable")
    return response.status === 204 ? null : response.json()
  }
  async play(listen) {
    const sequenced = this.policyValue === "sequence-v1"
    if (sequenced && !Number.isInteger(listen)) return this.enable()
    if (this.busy) return
    this.busy = true
    this.triggerTarget.disabled = true
    try {
      const player = this.application.getControllerForElementAndIdentifier(this.element, this.playerValue)
      if (!player) throw new Error("Player unavailable")
      if (sequenced) {
        const contexts = [window.__appMusicAudioCache?.synthContext, window.__appMusicAudioCache?.harmony?.synthContext, window.__appMusicAudio?.synthContext].filter(Boolean)
        if (contexts.some(context => context.state !== "running")) {
          window.__appMusicArenaAudioEnabled = false
          throw new Error("Audio permission required")
        }
      }
      // Unlock inside the original user gesture, before the network request.
      if (player.activatePlaybackContexts) await player.activatePlaybackContexts()
      else if (player.ensureAudioContext) await player.ensureAudioContext()
      if (sequenced) {
        const context = await (player.ensureAudioContext?.())
        if (context && context.state !== "running") throw new Error("Audio permission required")
      }
      const started = Date.now()
      const receipt = await this.post(this.startUrlValue, { generation: this.generationValue, ...(sequenced ? { listen } : {}) })
      if (receipt.already_started) throw new Error("Listening already started in another tab")
      await (this.playerValue === "harmony-player" || this.playerValue === "melody-player" ? player.playBlocked() : player.play())
      if (this.abort.signal.aborted) return
      if (this.statusTarget.dataset.state !== "completed") throw new Error("Playback did not complete")
      if (!receipt.replay) {
        const wait = Math.max(0, receipt.minimum_seconds * 1000 + 150 - (Date.now() - started))
        if (wait) await new Promise(resolve => setTimeout(resolve, wait))
        await this.post(this.completeUrlValue, { generation: this.generationValue, token: receipt.token, ...(sequenced ? { listen } : {}) })
      }
      this.triggerTarget.textContent = "↻ Ouvir novamente"
      if (sequenced) {
        this.finished.add(listen)
        this.showCue(listen === this.repetitionsValue ? "Escutas concluídas. Prepare sua resposta!" : "Faça uma pausa. A próxima escuta já vai começar.")
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        this.statusTarget.textContent = sequenced ? "Não foi possível confirmar esta escuta. A sala seguirá; esta rodada não será avaliada para você." : "A escuta não foi confirmada. Tente tocar novamente. Nenhuma resposta foi registrada."
        this.statusTarget.dataset.state = "unavailable"
      }
    } finally {
      this.busy = false
      if (!this.abort.signal.aborted) this.triggerTarget.disabled = false
    }
  }
}
