import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "feedback"]
  static values = {
    events: Array,
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

    this.invalidatePlayback()
    this.isPlaying = false
  }

  async play() {
    if (this.isPlaying) return

    const requestId = this.startPlaybackRequest()
    this.isPlaying = true
    this.setTriggersDisabled(true)

    try {
      const totalDuration = await this.performPlayback(requestId)
      if (!this.isPlaybackRequestCurrent(requestId)) return

      await this.sleep(totalDuration * 1000)
    } finally {
      if (this.isPlaybackRequestCurrent(requestId)) {
        this.setTriggersDisabled(false)
        this.isPlaying = false
      }
    }
  }

  repeat() {
    return this.play()
  }

  guardAnswer(event) {
    if (this.audioState.lastPlayedSignature === this.exerciseSignatureValue) return

    event.preventDefault()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.hidden = false
    }
  }

  async performPlayback(requestId) {
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

    for (let cycle = 0; cycle < this.playbackCyclesValue; cycle += 1) {
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
      if (cycle < this.playbackCyclesValue - 1) {
        cursor += quarterDuration * 0.4
      }
    }

    return (cursor - context.currentTime) + 0.12
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
    this.audioState.lastPlayedSignature = this.exerciseSignatureValue
    return this.audioState.playbackToken
  }

  isPlaybackRequestCurrent(requestId) {
    return this.audioState.playbackToken === requestId
  }

  invalidatePlayback() {
    this.audioState.playbackToken += 1
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
