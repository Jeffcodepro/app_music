import { Controller } from "@hotwired/stimulus"
import { activateArenaAudio } from "audio/arena_listening"

// PostgreSQL decides phases and points. Browser clocks only animate/display.
export default class extends Controller {
  static targets = ["content", "connection", "timer", "copyStatus", "announcement", "answerStatus", "readyNotice", "audio", "audioActivation"]
  static values = { url: String, settleUrl: String, audioReadyUrl: String, arenaUrl: String }

  connect() {
    this.stopped = false
    this.abort = new AbortController()
    this.seenPhases = new Set()
    this.seenMembers = new Set()
    this.playersInitialized = false
    this.seenReactions = new Set()
    this.visibility = () => { if (!document.hidden) this.schedule(0) }
    document.addEventListener("visibilitychange", this.visibility)
    this.adoptState()
    this.tickTimer = setInterval(() => this.tick(), 200)
    this.schedule(1000)
  }

  disconnect() {
    this.stopped = true
    this.abort?.abort()
    this.answerAbort?.abort()
    clearTimeout(this.pollTimer)
    clearInterval(this.tickTimer)
    document.removeEventListener("visibilitychange", this.visibility)
  }

  schedule(delay) {
    clearTimeout(this.pollTimer)
    if (!this.stopped) this.pollTimer = setTimeout(() => this.poll(), delay)
  }

  adoptState() {
    this.state = this.contentTarget.querySelector("[data-arena-session-state]")?.dataset
    if (this.submissionToken && this.submissionRound !== this.state?.roundId) {
      this.answerAbort?.abort()
      this.submissionToken = null
    }
    this.sequence = Number(this.state?.sequence)
    this.version = Number(this.state?.version)
    this.clockOffset = Date.parse(this.state?.serverNow) - Date.now()
    this.tick()
    if (this.state?.phase !== "audio_check") this.audioAckError = false
    if (this.hasAudioActivationTarget) this.audioActivationTarget.hidden = this.state?.listeningPolicy !== "sequence-v1" || this.state?.audioRequired === "false" || Boolean(window.__appMusicArenaAudioEnabled) || ["podium", "ended", "departed", "listening", "audio_check", "lobby"].includes(this.state?.phase)
    this.syncAudio()
    void this.syncAudioCheck()
    this.presentPhase()
    this.presentPodium()
    this.presentPlayers()
  }

  async activateAudio() {
    try {
      await activateArenaAudio()
      this.audioAckError = false
      if (this.hasAudioActivationTarget) this.audioActivationTarget.hidden = true
      await this.syncAudioCheck()
    } catch { this.audioAckError = true; this.connectionTarget.textContent = "Não foi possível ativar o áudio. Verifique a permissão do navegador." }
  }

  audioPermissionReady() {
    if (!globalThis.window?.__appMusicArenaAudioEnabled) return false
    const contexts = [window.__appMusicAudioCache?.synthContext, window.__appMusicAudioCache?.harmony?.synthContext, window.__appMusicAudio?.synthContext].filter(Boolean)
    return contexts.length > 0 && contexts.every(context => context.state === "running")
  }

  async syncAudioCheck() {
    if (this.state?.phase !== "audio_check" || this.state?.audioCheckNeedsActivation !== "true" || this.audioAckPending) return
    const ready = this.audioPermissionReady()
    const confirmed = this.state.audioCheckOwnReady === "true"
    if (ready === confirmed) return
    this.audioAckPending = true
    try {
      const response = await fetch(this.audioReadyUrlValue, { method: "POST", credentials: "same-origin", signal: this.abort.signal,
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": this.csrfToken() },
        body: JSON.stringify({ check_id: this.state.audioCheckId, ready }) })
      if (!response.ok) throw new Error("Audio readiness unavailable")
      await this.refreshContent()
      this.audioAckError = false
    } catch (error) {
      if (error.name !== "AbortError") { this.audioAckError = true; this.connectionTarget.textContent = "Não foi possível confirmar seu áudio. Confira a conexão e tente novamente antes do prazo." }
    } finally { this.audioAckPending = false }
  }

  syncAudio() {
    if (!this.hasAudioTarget) return
    const template = this.contentTarget.querySelector("[data-arena-audio-template]")
    const key = template?.dataset?.arenaAudioTemplate || ""
    if (this.audioKey !== key) {
      this.audioKey = key
      this.audioTarget.innerHTML = template?.innerHTML || ""
      this.audioTarget.hidden = !key
    }
    const guidance = this.audioTarget.querySelector?.("[data-arena-audio-guidance]")
    if (guidance && this.state?.listeningPolicy !== "sequence-v1" && this.state?.phase !== "listening") guidance.textContent = this.state?.phase === "countdown" ? "Escuta concluída. As respostas abrem após a contagem." : "As respostas estão abertas. Ouvir novamente não reinicia o cronômetro."
  }

  remainingSeconds() {
    const deadline = Date.parse(this.state?.nextTransitionAt || this.state?.deadline)
    if (!Number.isFinite(deadline) || !Number.isFinite(this.clockOffset)) return null
    return Math.max(0, Math.ceil((deadline - Date.now() - this.clockOffset) / 1000))
  }

  tick() {
    if (!this.hasTimerTarget) return
    if (this.state?.phase === "paused" || this.state?.roundState === "paused") { this.timerTarget.textContent = this.state?.pausedFrom === "ready" ? "Ⅱ" : "Pausado"; return }
    const phase = this.state?.phase
    if (phase === "audio_check") {
      const remaining = this.remainingSeconds()
      this.timerTarget.textContent = remaining === null ? "45s" : `${remaining}s`
      this.timerTarget.closest?.(".arena-preflight-clock")?.style?.setProperty("--remaining", `${(remaining || 0) / 45 * 100}%`)
      if (remaining !== this.lastAudioCountdown && remaining <= 5 && remaining > 0) {
        this.lastAudioCountdown = remaining
        if (!this.reducedMotion()) this.timerTarget.animate?.([{ transform: "scale(1.18)" }, { transform: "scale(1)" }], { duration: 350 })
        if (this.hasAnnouncementTarget) this.announcementTarget.textContent = `${remaining} segundos para ativar o áudio.`
      }
      return
    }
    if (phase === "listening") { this.timerTarget.textContent = "Tempo parado"; return }
    if (!['countdown', 'question', 'feedback'].includes(phase) && this.state?.roundState !== "answering") { this.timerTarget.textContent = "Encerrado"; return }
    const remaining = this.remainingSeconds()
    const bar = this.contentTarget.querySelector("[data-arena-answer-clock]")
    if (bar?.style) bar.style.width = `${phase === "question" ? Math.max(0, Math.min(100, (remaining || 0) / (Number(this.state?.durationSeconds) || 30) * 100)) : 100}%`
    this.timerTarget.textContent = remaining === null ? "—" : (phase === "countdown" ? String(remaining || "Já!") : `${remaining}s`)
    if (phase === "countdown" && remaining !== this.lastCountdown) {
      this.lastCountdown = remaining
      if (!this.reducedMotion()) this.timerTarget.animate?.([{ transform: "scale(.85)", opacity: .5 }, { transform: "scale(1)", opacity: 1 }], { duration: 320, easing: "ease-out" })
    }
  }

  reducedMotion() { return globalThis.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true }

  presentPodium() {
    if (this.state?.phase !== "podium") return
    const panel = this.contentTarget.querySelector("[data-arena-celebration]")
    if (!panel?.style) return
    const key = `${this.urlValue}:${this.state.phaseStartedAt}`
    if (this.podiumKey !== key) { this.podiumKey = key; this.podiumStartedAt = Date.now(); this.podiumSkipped = false }
    if (this.reducedMotion() || this.podiumSkipped) { panel.classList?.remove("is-celebrating"); return }
    const elapsed = Math.max(0, Date.now() - this.podiumStartedAt)
    panel.style.setProperty("--podium-elapsed", `${-elapsed}ms`)
    panel.classList?.add("is-celebrating")
  }

  skipPodium() {
    this.podiumSkipped = true
    this.contentTarget.querySelector("[data-arena-celebration]")?.classList.remove("is-celebrating")
    this.contentTarget.querySelector(".arena-phase-title")?.focus({ preventScroll: true })
  }

  cancelDisclosure(event) { event.currentTarget.closest("details").open = false }

  presentPlayers() {
    const points = this.contentTarget.querySelector("[data-arena-points]")
    const value = Number(points?.textContent)
    if (Number.isFinite(value)) {
      if (this.lastPoints !== undefined && value > this.lastPoints && !this.reducedMotion()) points?.classList?.add("is-score-pop")
      this.lastPoints = value
    }
    this.seenAudioReady ||= new Set()
    for (const player of this.contentTarget.querySelectorAll("[data-arena-audio-ready-key]")) {
      const key = player.dataset?.arenaAudioReadyKey
      if (!key || this.seenAudioReady.has(key)) continue
      this.seenAudioReady.add(key)
      if (!this.reducedMotion()) player.classList?.add("is-sound-ready")
    }
    const arrivals = []
    const currentKeys = new Set()
    for (const player of this.contentTarget.querySelectorAll("[data-arena-member-key]")) {
      const key = player.dataset?.arenaMemberKey
      if (!key) continue
      currentKeys.add(key)
      if (this.seenMembers.has(key)) continue
      this.seenMembers.add(key)
      if (this.playersInitialized && player.dataset?.arenaMemberName) arrivals.push({ key, name: player.dataset.arenaMemberName })
      if (!this.reducedMotion()) player.classList?.add("is-joining")
    }
    this.playersInitialized = true
    if (this.hasReadyNoticeTarget) {
      if (this.state?.phase !== "lobby") this.readyNoticeTarget.textContent = ""
      else if (this.state?.host === "true" && arrivals.length) {
        this.noticeMemberKeys = arrivals.map(player => player.key)
        this.readyNoticeTarget.textContent = arrivals.length === 1 ? `${arrivals[0].name} está pronto!` : `${arrivals.map(player => player.name).join(", ")} estão prontos!`
      } else if (this.noticeMemberKeys?.some(key => !currentKeys.has(key))) this.readyNoticeTarget.textContent = ""
    }
    for (const [selector,kind] of [["[data-arena-answer-received]","answer"],["[data-arena-result]","result"]]) {
      const panel = this.contentTarget.querySelector(selector)
      const key = `${this.state?.roundId}:${kind}`
      if (panel && !this.seenReactions.has(key)) {
        this.seenReactions.add(key)
        if (!this.reducedMotion()) panel.classList?.add("is-reacting")
      }
    }
  }

  presentPhase() {
    if (!this.state?.phase) return
    const key = `${this.urlValue}:${this.state.roundId}:${this.state.phase}:${this.state.phaseStartedAt || ''}`
    if (this.phaseKey === key) return
    const previous = this.phaseKey
    this.phaseKey = key
    const panel = this.contentTarget.querySelector("[data-arena-phase-panel]")
    if (!this.seenPhases.has(key)) {
      this.seenPhases.add(key)
      if (["audio_check", "podium"].includes(this.state.phase)) panel?.scrollIntoView?.({ block: "start", behavior: this.reducedMotion() ? "auto" : "smooth" })
      if (!this.reducedMotion()) panel?.classList?.add(this.state.phase === "podium" ? "is-celebrating" : "is-entering")
    }
    if (this.hasAnswerStatusTarget) this.answerStatusTarget.textContent = ""
    if (this.hasAnnouncementTarget) {
      const messages = { countdown: "Prepare-se para a próxima questão.", question: "Questão aberta. Escolha sua resposta.", feedback: "Resultado da rodada disponível.", podium: "Partida concluída. Pódio disponível.", listening: "Ouça o trecho antes da abertura das respostas.", audio_check: "Ative seu áudio em até 45 segundos. O jogo começa antes se todos estiverem prontos.", paused: "Partida pausada." }
      this.announcementTarget.textContent = messages[this.state.phase] || "Sala atualizada."
    }
    if (previous) panel?.querySelector?.(".arena-phase-title")?.focus({ preventScroll: true })
  }

  shouldSettle(snapshot) {
    if (snapshot.departed) return false
    if (snapshot.phase === "audio_check") return snapshot.audio_check?.all_ready || snapshot.participant_count === 0 || Date.now() + this.clockOffset >= Date.parse(snapshot.next_transition_at)
    if (snapshot.state === "paused" || ['completed', 'cancelled', 'expired'].includes(snapshot.state)) return false
    if (snapshot.phase === "listening" && snapshot.round?.playback?.policy === "sequence-v1") return Date.now() + this.clockOffset >= Date.parse(snapshot.next_transition_at)
    if (snapshot.phase === "listening") return snapshot.round?.playback?.required_count > 0 && snapshot.round.playback.ready_count >= snapshot.round.playback.required_count
    if (snapshot.round?.state === "ready" && snapshot.next_transition_at) return Date.now() + this.clockOffset >= Date.parse(snapshot.next_transition_at)
    if (snapshot.experience === "party") {
      const due = Date.parse(snapshot.next_transition_at)
      const now = Date.now() + this.clockOffset
      const allAnswered = snapshot.phase === "question" && snapshot.participant_count > 0 && snapshot.round?.answered_count >= snapshot.participant_count
      return allAnswered || (Number.isFinite(due) && now >= due)
    }
    return snapshot.round?.state === "answering" && this.remainingSeconds() === 0
  }

  async poll() {
    if (this.stopped || this.polling) return
    this.polling = true
    try {
      const response = await fetch(`${this.urlValue}.json`, { credentials: "same-origin", cache: "no-store", headers: { Accept: "application/json" }, signal: this.abort.signal })
      if (response.status === 401 || response.status === 404) {
        this.stopped = true
        this.connectionTarget.textContent = "A sala não está disponível. Volte para a Arena ou entre novamente."
        return
      }
      if (!response.ok) throw new Error("snapshot unavailable")
      const snapshot = await response.json()
      this.clockOffset = Date.parse(snapshot.server_now) - Date.now()
      if (snapshot.phase === "audio_excluded") {
        this.stopped = true
        window.location.assign(`${this.arenaUrlValue}?audio=expired`)
        return
      }
      const invitationExpired = snapshot.invite && String(snapshot.invite.expired) !== this.state?.inviteExpired
      if (snapshot.sequence !== this.sequence || snapshot.version !== this.version || invitationExpired) await this.refreshContent()
      if (snapshot.phase === "audio_check") await this.syncAudioCheck()
      if (this.shouldSettle(snapshot)) await this.settle()
      if (!this.audioAckError) this.connectionTarget.textContent = ""
    } catch (error) {
      if (error.name !== "AbortError" && !this.stopped) this.connectionTarget.textContent = "Reconectando à sala… Suas respostas registradas continuam salvas."
    } finally {
      this.polling = false
      this.schedule(document.hidden ? 4000 : 1000)
    }
  }

  async refreshContent() {
    const roundId = this.state?.roundId
    const response = await fetch(`${this.urlValue}?fragment=1`, { credentials: "same-origin", cache: "no-store", headers: { Accept: "text/html" }, signal: this.abort.signal })
    if (!response.ok) throw new Error("view unavailable")
    const html = await response.text()
    const incoming = response.headers?.get("X-Arena-Sequence")
    if (this.stopped || (incoming != null && Number(incoming) < this.sequence)) return
    const phase = this.phaseKey
    const attemptKey = this.contentTarget.querySelector('input[name="idempotency_key"]')?.value
    const director = this.contentTarget.querySelector('.arena-director')
    const directorOpen = director?.open
    const persistentControls = [...this.contentTarget.querySelectorAll('[data-arena-persistent-control]')].filter(control => control.open).map(control => control.dataset.arenaPersistentControl)
    const focusedPersistent = document.activeElement?.closest?.('[data-arena-persistent-control]')?.dataset?.arenaPersistentControl
    const focusedPersistentAction = document.activeElement?.dataset?.arenaPersistentAction
    const removalControls = [...this.contentTarget.querySelectorAll('[data-arena-member-controls]')].filter(control => control.open && control.dataset?.arenaMemberControls).map(control => control.dataset.arenaMemberControls)
    const focusedRemoval = document.activeElement?.closest?.('[data-arena-member-controls]')?.dataset?.arenaMemberControls
    const removalButtonFocused = document.activeElement?.dataset?.arenaRemove
    const selected = this.contentTarget.querySelector('input[name="option_id"]:checked')?.value
    const focused = document.activeElement
    const directorFocused = director?.contains?.(focused)
    const focusedCommand = directorFocused ? focused?.dataset?.arenaCommand : null
    const focusedOption = focused?.matches?.('[name="option_id"]') ? focused.value : null
    this.contentTarget.innerHTML = html
    this.adoptState()
    if (roundId === this.state?.roundId) {
      const identity = this.contentTarget.querySelector('input[name="idempotency_key"]')
      if (identity && attemptKey) identity.value = attemptKey
      const inputs = [...this.contentTarget.querySelectorAll('[name="option_id"]')]
      const current = inputs.find(input => input.value === selected)
      if (current) current.checked = true
      const focus = inputs.find(input => input.value === focusedOption)
      if (focus) focus.focus({ preventScroll: true })
      if (this.submissionToken) this.setAnswerPending(true)
    }
    if (phase === this.phaseKey) {
      const replacement = this.contentTarget.querySelector('.arena-director')
      if (replacement && directorOpen !== undefined) replacement.open = directorOpen
      for (const name of persistentControls) {
        const control = this.contentTarget.querySelector(`[data-arena-persistent-control="${name}"]`)
        if (control) control.open = true
      }
      if (focusedPersistent) {
        this.contentTarget.querySelector(`[data-arena-persistent-control="${focusedPersistent}"]`)?.querySelector(focusedPersistentAction ? `[data-arena-persistent-action="${focusedPersistentAction}"]` : 'summary')?.focus({ preventScroll: true })
      } else if (directorFocused) {
        const control = focusedCommand ? replacement?.querySelector?.(`[data-arena-command="${focusedCommand}"]`) : replacement?.querySelector?.('summary')
        control?.focus({ preventScroll: true })
      }
    }
    if (phase === this.phaseKey) {
      for (const key of removalControls) {
        const replacement = this.contentTarget.querySelector(`[data-arena-member-controls="${key}"]`)
        if (replacement) replacement.open = true
      }
      if (focusedRemoval) this.contentTarget.querySelector(`[data-arena-member-controls="${focusedRemoval}"]`)?.querySelector(removalButtonFocused ? 'button' : 'summary')?.focus({ preventScroll: true })
    }
  }

  async settle() {
    const response = await fetch(this.settleUrlValue, { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "X-CSRF-Token": this.csrfToken(), Accept: "application/json" }, signal: this.abort.signal })
    if (!response.ok) throw new Error("settlement unavailable")
    await this.refreshContent()
  }

  csrfToken() { return document.querySelector('meta[name="csrf-token"]')?.content || "" }

  setAnswerPending(pending) {
    const fieldset = this.contentTarget.querySelector(".arena-answer-form fieldset")
    if (fieldset) fieldset.disabled = pending || this.state?.phase !== "question"
  }

  async submitAnswer(event) {
    event.preventDefault()
    if (this.submissionToken || !event.submitter) return
    const token = {}
    this.submissionToken = token
    this.submissionRound = this.state?.roundId
    this.answerAbort = new AbortController()
    const form = event.currentTarget
    const body = new FormData(form)
    body.set(event.submitter.name, event.submitter.value)
    this.setAnswerPending(true)
    const status = this.hasAnswerStatusTarget ? this.answerStatusTarget : this.connectionTarget
    status.textContent = ""
    try {
      const response = await fetch(form.action, { method: "POST", credentials: "same-origin", cache: "no-store", body,
        headers: { "X-CSRF-Token": this.csrfToken(), Accept: "application/json" }, signal: this.answerAbort.signal })
      if (this.submissionToken !== token || this.stopped) return
      if (response.ok) {
        await this.refreshContent()
        status.textContent = ""
      } else {
        const message = await response.json()
        await this.refreshContent()
        status.textContent = message.error || "Atualize a sala e tente novamente."
      }
    } catch (error) {
      if (error.name !== "AbortError" && !this.stopped) status.textContent = "Não foi possível confirmar o envio. Tente novamente; sua resposta não foi marcada como errada."
    } finally {
      if (this.submissionToken === token) { this.submissionToken = null; this.setAnswerPending(false) }
    }
  }

  async copy(event) {
    const button = event.currentTarget
    const status = this.hasCopyStatusTarget ? this.copyStatusTarget : this.connectionTarget
    try {
      await navigator.clipboard.writeText(button.dataset.copyText)
      status.textContent = button.textContent.includes("resultado") ? "Resultado copiado. Compartilhe com quem você quiser." : (button.textContent.includes("link") ? "Link copiado. Compartilhe com quem você quer convidar." : "Código copiado.")
    } catch { status.textContent = button.textContent.includes("resultado") ? "Selecione o texto do seu resultado e copie manualmente." : "Selecione o campo do código ou link e copie manualmente." }
  }

  selectText(event) { event.currentTarget.select() }
}
