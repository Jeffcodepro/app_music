import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "feedback", "status"]
  static values = {
    events: Array,
    meter: Object,
    measureCount: Number,
    totalSteps: Number,
    tempoBpm: Number,
    countInBeats: Number,
    exerciseSignature: String,
    metronomeDuringPattern: Boolean,
    playbackCycles: Number
  }

  connect() {
    this.audioState = window.__appMusicAudio ||= {}
    this.audioState.synthContext ||= null
    this.audioState.playbackToken ||= 0
    this.audioState.activeRhythmNodes ||= []
    this.audioState.lastPlayedSignature ||= null
    this.audioState.rhythmNoiseBuffer ||= null

    this.isPlaying = false
    this.invalidatePlayback()
  }

  disconnect() {
    this.isPlaying = false
    this.invalidatePlayback()
  }

  exerciseSignatureValueChanged(currentValue, previousValue) {
    if (!this.audioState || !previousValue || currentValue === previousValue) return

    this.setPlaybackStatus("Pronto para ouvir", "ready")
    this.invalidatePlayback()
    this.isPlaying = false
  }

  setPlaybackStatus(message, state) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = state
  }

  async play() {
    if (this.isPlaying) return

    const requestId = this.startPlaybackRequest()
    this.isPlaying = true
    this.setTriggersDisabled(true)
    this.setPlaybackStatus("Preparando áudio…", "loading")

    try {
      const totalDuration = await this.performPlayback(requestId)
      if (!this.isPlaybackRequestCurrent(requestId)) return

      if (!Number.isFinite(totalDuration) || totalDuration <= 0) throw new RangeError("Invalid playback duration")
      this.setPlaybackStatus("Reproduzindo…", "playing")
      await this.sleep(totalDuration * 1000)
      if (this.isPlaybackRequestCurrent(requestId)) {
        this.audioState.lastPlayedSignature = this.exerciseSignatureValue
        this.setPlaybackStatus("Escuta concluída. Você pode responder.", "completed")
      }
    } catch (error) {
      if (this.isPlaybackRequestCurrent(requestId)) {
        this.invalidatePlayback()
        this.isPlaying = false
        this.setTriggersDisabled(false)
        this.showPlaybackError()
        this.setPlaybackStatus("Áudio indisponível. Tente novamente.", "unavailable")
      }
      console.warn("Exercise audio could not be completed", error)
    } finally {
      if (this.isPlaybackRequestCurrent(requestId)) {
        this.setTriggersDisabled(false)
        this.isPlaying = false
      }
    }
  }

  stop() {
    this.isPlaying = false
    this.invalidatePlayback()
    this.setTriggersDisabled(false)
    this.setPlaybackStatus("Pronto para ouvir", "ready")
  }

  repeat() {
    return this.play()
  }

  showPlaybackError() {
    let message = this.element.querySelector("[data-playback-error]")
    if (!message) {
      message = document.createElement("p")
      message.dataset.playbackError = "true"
      message.setAttribute("role", "status")
      this.element.prepend(message)
    }
    message.textContent = "Não foi possível concluir o áudio. Tente reproduzir novamente; nenhuma resposta foi contabilizada."
  }

  guardAnswer(event) {
    if (!this.isPlaying && this.audioState.lastPlayedSignature === this.exerciseSignatureValue) {
      const status = event.currentTarget.form?.querySelector('[name="playback_status"]')
      if (status) status.value = "ready"
      return
    }

    event.preventDefault()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.hidden = false
    }
  }

  async performPlayback(requestId) {
    if (this.hasMeterValue) return this.performMetricalPlayback(requestId)
    const context = await this.ensureAudioContext()
    if (!this.isPlaybackRequestCurrent(requestId)) return 0

    const sixteenthDuration = 60 / this.tempoBpmValue / 4
    const quarterDuration = sixteenthDuration * 4
    const measureDuration = sixteenthDuration * 16
    let cursor = context.currentTime + 0.05

    for (let beat = 0; beat < this.countInBeatsValue; beat += 1) {
      this.scheduleMetronomeClick(cursor, beat === 0)
      cursor += quarterDuration
    }

    // One complete pattern per action, including legacy assignments with two
    // cycles in their immutable payload. Replay is always an explicit action.
    if (this.metronomeDuringPatternValue) {
      for (let beat = 0; beat < 4; beat += 1) {
        this.scheduleMetronomeClick(cursor + (beat * quarterDuration), beat === 0)
      }
    }
    this.eventsValue.forEach((event) => {
      const startAt = cursor + (event.start_step * sixteenthDuration)
      const duration = Math.max(0.07, (event.duration_steps * sixteenthDuration) * 0.72)
      this.scheduleRhythmHit(startAt, duration, event.start_step % 4 === 0)
    })
    cursor += measureDuration

    return (cursor - context.currentTime) + 0.12
  }

  async performMetricalPlayback(requestId) {
    const m = this.meterValue
    const { numerator: n, denominator: d, groups, kind, bpm_unit_steps: bpmUnit } = m
    const bars = this.measureCountValue
    if (!Number.isInteger(n) || n < 2 || n > 13 || ![2, 4, 8, 16].includes(d) ||
        !Array.isArray(groups) || !groups.every(g => Number.isInteger(g) && g > 0) || groups.reduce((a, b) => a + b, 0) !== n ||
        !['simple', 'compound', 'additive'].includes(kind) || !Number.isFinite(this.tempoBpmValue) || this.tempoBpmValue <= 0 || this.tempoBpmValue > 240 ||
        ![1, 2].includes(bars)) throw new RangeError('Invalid meter')
    const unit = 16 / d
    const measure = n * unit
    if (bpmUnit !== (kind === 'compound' ? 3 * unit : unit) || this.totalStepsValue !== measure * bars ||
        (kind === 'simple' && !groups.every(g => g === 1)) || (kind === 'compound' && !groups.every(g => g === 3)) ||
        (kind === 'additive' && !groups.every(g => [2, 3].includes(g))) ||
        !Array.isArray(this.eventsValue) || !this.eventsValue.length || this.eventsValue.some(e => !Number.isInteger(e.start_step) || e.start_step < 0 || ![1,2,3,4,6,8,12,16].includes(e.duration_steps) || e.start_step + e.duration_steps > this.totalStepsValue)) {
      throw new RangeError('Invalid rhythmic phrase')
    }
    const stepSeconds = 60 / this.tempoBpmValue / bpmUnit
    const groupStarts = []; let cursor = 0
    groups.forEach(group => { groupStarts.push(cursor); cursor += group * unit })
    const clicks = kind === 'additive' ? Array.from({ length: n }, (_, i) => i * unit) : groupStarts
    const accents = kind === 'additive' ? groupStarts : [0]
    const context = await this.ensureAudioContext()
    if (!this.isPlaybackRequestCurrent(requestId)) return 0
    const startAt = context.currentTime + 0.05
    clicks.forEach(step => this.scheduleMetronomeClick(startAt + step * stepSeconds, accents.includes(step)))
    const patternStart = startAt + measure * stepSeconds
    if (this.metronomeDuringPatternValue) {
      for (let bar = 0; bar < bars; bar++) clicks.forEach(step => this.scheduleMetronomeClick(patternStart + (bar * measure + step) * stepSeconds, accents.includes(step)))
    }
    this.eventsValue.forEach(event => this.scheduleRhythmHit(patternStart + event.start_step * stepSeconds,
      Math.max(0.035, event.duration_steps * stepSeconds * 0.72), groupStarts.includes(event.start_step % measure)))
    return 0.05 + measure * (1 + bars) * stepSeconds + 0.12
  }

  async ensureAudioContext() {
    if (!this.audioState.synthContext || this.audioState.synthContext.state === "closed") {
      const AudioContext = window.AudioContext || window.webkitAudioContext
      this.audioState.synthContext = new AudioContext()
    }

    if (this.audioState.synthContext.state === "suspended") {
      await this.audioState.synthContext.resume()
    }

    return this.audioState.synthContext
  }

  scheduleMetronomeClick(startAt, accented) {
    this.scheduleClickLayer({
      startAt,
      layers: accented ? this.accentedMetronomeLayers() : this.regularMetronomeLayers()
    })
  }

  scheduleRhythmHit(startAt, duration, accented) {
    this.scheduleNoiseBurst({
      startAt,
      duration: accented ? 0.055 : 0.045,
      gain: accented ? 0.28 : 0.21,
      filterFrequency: accented ? 1800 : 1450,
      q: accented ? 0.95 : 0.82
    })

    this.scheduleClickLayer({
      startAt,
      layers: accented ? this.accentedRhythmLayers(duration) : this.regularRhythmLayers(duration)
    })
  }

  scheduleClickLayer({ startAt, layers }) {
    layers.forEach((layer) => {
      this.schedulePulse({ startAt, ...layer })
    })
  }

  schedulePulse({ startAt, frequency, gain, duration, type, endFrequency = null, attack = 0.006 }) {
    const context = this.audioState.synthContext
    const oscillator = context.createOscillator()
    const gainNode = context.createGain()

    oscillator.type = type
    oscillator.frequency.setValueAtTime(frequency, startAt)
    oscillator.frequency.exponentialRampToValueAtTime(endFrequency || Math.max(180, frequency * 0.68), startAt + duration)

    gainNode.gain.setValueAtTime(0.0001, startAt)
    gainNode.gain.exponentialRampToValueAtTime(gain, startAt + attack)
    gainNode.gain.exponentialRampToValueAtTime(0.0001, startAt + duration)

    oscillator.connect(gainNode)
    gainNode.connect(context.destination)

    oscillator.start(startAt)
    oscillator.stop(startAt + duration + 0.02)
    this.trackNode(oscillator)
  }

  scheduleNoiseBurst({ startAt, duration, gain, filterFrequency, q }) {
    const context = this.audioState.synthContext
    const source = context.createBufferSource()
    const filter = context.createBiquadFilter()
    const gainNode = context.createGain()

    source.buffer = this.rhythmNoiseBuffer()
    filter.type = "bandpass"
    filter.frequency.setValueAtTime(filterFrequency, startAt)
    filter.Q.setValueAtTime(q, startAt)

    gainNode.gain.setValueAtTime(0.0001, startAt)
    gainNode.gain.exponentialRampToValueAtTime(gain, startAt + 0.002)
    gainNode.gain.exponentialRampToValueAtTime(0.0001, startAt + duration)

    source.connect(filter)
    filter.connect(gainNode)
    gainNode.connect(context.destination)

    source.start(startAt)
    source.stop(startAt + duration + 0.02)
    this.trackNode(source)
  }

  trackNode(node) {
    this.audioState.activeRhythmNodes.push(node)
    node.onended = () => {
      this.audioState.activeRhythmNodes = this.audioState.activeRhythmNodes.filter((entry) => entry !== node)
    }
  }

  startPlaybackRequest() {
    this.invalidatePlayback()
    this.audioState.playbackToken += 1
    return this.audioState.playbackToken
  }

  isPlaybackRequestCurrent(requestId) {
    return this.audioState.playbackToken === requestId
  }

  invalidatePlayback() {
    this.audioState.playbackToken += 1
    this.audioState.lastPlayedSignature = null
    this.audioState.activeRhythmNodes.forEach((node) => {
      try {
        node.stop()
      } catch (_error) {
      }
    })
    this.audioState.activeRhythmNodes = []
  }

  setTriggersDisabled(disabled) {
    this.triggerTargets.forEach((target) => {
      target.disabled = disabled
    })
  }

  sleep(durationInMilliseconds) {
    return new Promise((resolve) => window.setTimeout(resolve, durationInMilliseconds))
  }

  rhythmNoiseBuffer() {
    if (this.audioState.rhythmNoiseBuffer) return this.audioState.rhythmNoiseBuffer

    const context = this.audioState.synthContext
    const buffer = context.createBuffer(1, context.sampleRate * 0.18, context.sampleRate)
    const channel = buffer.getChannelData(0)

    for (let index = 0; index < channel.length; index += 1) {
      channel[index] = (Math.random() * 2) - 1
    }

    this.audioState.rhythmNoiseBuffer = buffer
    return buffer
  }

  regularMetronomeLayers() {
    return [
      { frequency: 1580, endFrequency: 1120, gain: 0.32, duration: 0.052, type: "square", attack: 0.004 },
      { frequency: 760, endFrequency: 420, gain: 0.12, duration: 0.07, type: "triangle", attack: 0.006 }
    ]
  }

  accentedMetronomeLayers() {
    return [
      { frequency: 1960, endFrequency: 1240, gain: 0.42, duration: 0.06, type: "square", attack: 0.003 },
      { frequency: 980, endFrequency: 480, gain: 0.18, duration: 0.085, type: "triangle", attack: 0.005 }
    ]
  }

  regularRhythmLayers(duration) {
    return [
      { frequency: 540, endFrequency: 280, gain: 0.12, duration: Math.max(0.06, duration * 0.5), type: "triangle", attack: 0.003 },
      { frequency: 1260, endFrequency: 840, gain: 0.04, duration: 0.028, type: "square", attack: 0.002 }
    ]
  }

  accentedRhythmLayers(duration) {
    return [
      { frequency: 620, endFrequency: 320, gain: 0.16, duration: Math.max(0.075, duration * 0.56), type: "triangle", attack: 0.003 },
      { frequency: 1480, endFrequency: 980, gain: 0.06, duration: 0.032, type: "square", attack: 0.002 }
    ]
  }
}
