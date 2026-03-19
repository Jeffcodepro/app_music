import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "feedback"]
  static values = {
    sequence: Array,
    exerciseSignature: String,
    instrument: String
  }

  connect() {
    this.audioState = window.__appMusicAudio ||= {}
    this.audioState.soundfontPlayers ||= {}
    this.audioState.soundfontPromises ||= {}
    this.audioState.synthContext ||= null
    this.audioState.activePlaybackHandles ||= []
    this.audioState.playbackToken ||= 0
    this.audioState.lastPlayedSignature ||= null

    this.invalidatePlayback()
    this.isPlaying = false
    this.lastStyle = this.defaultPlaybackStyle()
    this.preloadCurrentInstrument()
  }

  disconnect() {
    this.isPlaying = false
    this.invalidatePlayback()
  }

  instrumentValueChanged() {
    this.preloadCurrentInstrument()
    if (!this.canPlayBlocked() && this.lastStyle === "blocked") {
      this.lastStyle = "broken"
    }
  }

  playBlocked() {
    return this.play("blocked")
  }

  playBroken() {
    return this.play("broken")
  }

  repeat() {
    const style = this.audioState.lastPlayedSignature === this.exerciseSignatureValue ? this.lastStyle : this.defaultPlaybackStyle()
    return this.play(style)
  }

  guardAnswer(event) {
    if (this.audioState.lastPlayedSignature === this.exerciseSignatureValue) return

    event.preventDefault()
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.hidden = false
    }
  }

  exerciseSignatureValueChanged(currentValue, previousValue) {
    if (!this.audioState || !previousValue || currentValue === previousValue) return

    this.invalidatePlayback()
    this.isPlaying = false
    this.lastStyle = this.defaultPlaybackStyle()
  }

  async play(style) {
    if (this.isPlaying) return

    const resolvedStyle = this.resolvedStyle(style)
    const requestId = this.startPlaybackRequest()
    this.isPlaying = true
    this.lastStyle = resolvedStyle
    this.setTriggersDisabled(true)

    try {
      const totalDuration = await this.playSequence(resolvedStyle, requestId)
      if (!this.isPlaybackRequestCurrent(requestId)) return

      await this.sleep(totalDuration * 1000)
    } finally {
      if (this.isPlaybackRequestCurrent(requestId)) {
        this.setTriggersDisabled(false)
        this.isPlaying = false
      }
    }
  }

  async playSequence(style, requestId) {
    const player = await this.waitForSoundfontPlayer(2200)
    if (!this.isPlaybackRequestCurrent(requestId)) return 0
    if (player) return this.playSequenceWithSoundfont(player, style, requestId)

    return this.playSequenceWithSynth(style, requestId)
  }

  async playSequenceWithSoundfont(player, style, requestId) {
    const audioContext = await this.ensureToneAudioContext(true)
    if (!this.isPlaybackRequestCurrent(requestId)) return 0

    const noteDuration = style === "blocked" ? 1.2 : 0.52
    const noteGap = style === "blocked" ? 0 : 0.13
    const chordGap = style === "blocked" ? 0.4 : 0.24
    let cursor = audioContext.currentTime + 0.05

    this.sequenceValue.forEach((chord) => {
      if (style === "blocked") {
        this.scheduleBlockedSoundfontChord(player, chord.pitches, cursor, noteDuration)
        cursor += noteDuration + chordGap
      } else {
        cursor += this.scheduleBrokenSoundfontChord(player, chord.pitches, cursor, noteDuration, noteGap) + chordGap
      }
    })

    return (cursor - audioContext.currentTime) + 0.14
  }

  scheduleBlockedSoundfontChord(player, pitches, startAt, durationInSeconds) {
    pitches.forEach((pitch) => {
      this.trackPlaybackHandle(player.play(this.normalizePitchForSoundfont(pitch), startAt, {
        duration: durationInSeconds,
        gain: this.soundfontGain()
      }))
    })
  }

  scheduleBrokenSoundfontChord(player, pitches, startAt, durationInSeconds, noteGap) {
    let cursor = startAt

    pitches.forEach((pitch) => {
      this.trackPlaybackHandle(player.play(this.normalizePitchForSoundfont(pitch), cursor, {
        duration: durationInSeconds,
        gain: this.soundfontGain()
      }))
      cursor += durationInSeconds + noteGap
    })

    return cursor - startAt
  }

  async playSequenceWithSynth(style, requestId) {
    this.audioContext = await this.ensureAudioContext()
    if (!this.isPlaybackRequestCurrent(requestId)) return 0

    const preset = this.instrumentPreset()
    const chordDuration = style === "blocked" ? 1.15 : 0.58
    const noteGap = style === "blocked" ? 0 : 0.15
    const chordGap = style === "blocked" ? 0.4 : 0.28
    let cursor = this.audioContext.currentTime + 0.04

    this.sequenceValue.forEach((chord) => {
      if (style === "blocked") {
        this.scheduleBlockedSynthChord(chord.frequencies, cursor, chordDuration)
        cursor += chordDuration + chordGap
      } else {
        cursor += this.scheduleBrokenSynthChord(chord.frequencies, cursor, chordDuration, noteGap) + chordGap
      }
    })

    return (cursor - this.audioContext.currentTime) + preset.release + 0.14
  }

  scheduleBlockedSynthChord(frequencies, startAt, durationInSeconds) {
    frequencies.forEach((frequency) => {
      this.scheduleTone(frequency, startAt, durationInSeconds)
    })
  }

  scheduleBrokenSynthChord(frequencies, startAt, durationInSeconds, noteGap) {
    let cursor = startAt

    frequencies.forEach((frequency) => {
      this.scheduleTone(frequency, cursor, durationInSeconds)
      cursor += durationInSeconds + noteGap
    })

    return cursor - startAt
  }

  async preloadCurrentInstrument() {
    if (!this.canUseSoundfont()) return null

    try {
      return await this.soundfontInstrument()
    } catch (error) {
      console.warn("Soundfont preload failed, keeping synth fallback.", error)
      return null
    }
  }

  async waitForSoundfontPlayer(timeoutInMilliseconds) {
    if (!this.canUseSoundfont()) return null

    const loadPromise = this.soundfontInstrument().catch((error) => {
      console.warn("Soundfont load failed during playback, using synth fallback.", error)
      return null
    })

    let timeoutId
    const timeoutPromise = new Promise((resolve) => {
      timeoutId = window.setTimeout(() => resolve(null), timeoutInMilliseconds)
    })

    const player = await Promise.race([loadPromise, timeoutPromise])
    window.clearTimeout(timeoutId)
    return player
  }

  canUseSoundfont() {
    return Boolean(window.Tone && window.Soundfont)
  }

  canPlayBlocked() {
    return ["piano", "guitar", "organ"].includes(this.instrumentValue)
  }

  defaultPlaybackStyle() {
    return this.canPlayBlocked() ? "blocked" : "broken"
  }

  resolvedStyle(style) {
    if (style === "blocked" && !this.canPlayBlocked()) return "broken"

    return style || this.defaultPlaybackStyle()
  }

  async ensureToneAudioContext(activate = false) {
    const tone = window.Tone
    if (activate) {
      await tone.start()
    }

    const context = tone.getContext ? tone.getContext() : tone.context
    return context.rawContext || context
  }

  async soundfontInstrument() {
    const instrumentId = this.instrumentValue
    if (this.audioState.soundfontPlayers[instrumentId]) {
      return this.audioState.soundfontPlayers[instrumentId]
    }

    if (!this.audioState.soundfontPromises[instrumentId]) {
      this.audioState.soundfontPromises[instrumentId] = this.loadSoundfontInstrument(instrumentId)
    }

    return this.audioState.soundfontPromises[instrumentId]
  }

  async loadSoundfontInstrument(instrumentId) {
    try {
      const audioContext = await this.ensureToneAudioContext(false)
      const player = await window.Soundfont.instrument(
        audioContext,
        this.soundfontProgramName(instrumentId),
        {
          soundfont: "MusyngKite",
          format: "mp3"
        }
      )

      this.audioState.soundfontPlayers[instrumentId] = player
      delete this.audioState.soundfontPromises[instrumentId]
      return player
    } catch (error) {
      delete this.audioState.soundfontPromises[instrumentId]
      throw error
    }
  }

  soundfontProgramName(instrumentId = this.instrumentValue) {
    const mappings = {
      piano: "acoustic_grand_piano",
      flute: "flute",
      clarinet: "clarinet",
      guitar: "acoustic_guitar_nylon",
      organ: "drawbar_organ"
    }

    return mappings[instrumentId] || mappings.piano
  }

  soundfontGain() {
    const gains = {
      piano: 1.12,
      flute: 0.95,
      clarinet: 0.95,
      guitar: 1,
      organ: 0.9
    }

    return gains[this.instrumentValue] || 1
  }

  normalizePitchForSoundfont(pitchName) {
    const sanitizedPitch = pitchName
      .toString()
      .trim()
      .replace(/♯/g, "#")
      .replace(/♭/g, "b")

    const match = sanitizedPitch.match(/^([A-Ga-g])(#{1,2}|b{1,2})?(-?\d+)$/)
    if (!match) return sanitizedPitch

    const [, rawNote, rawAccidental = "", rawOctave] = match
    const semitoneOffsets = {
      C: 0,
      D: 2,
      E: 4,
      F: 5,
      G: 7,
      A: 9,
      B: 11
    }

    const note = rawNote.toUpperCase()
    let midi = (Number(rawOctave) + 1) * 12 + semitoneOffsets[note]

    rawAccidental.split("").forEach((accidental) => {
      midi += accidental == "#" ? 1 : -1
    })

    const octave = Math.floor(midi / 12) - 1
    const pitchClasses = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return `${pitchClasses[((midi % 12) + 12) % 12]}${octave}`
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

  scheduleTone(frequency, startAt, durationInSeconds) {
    const preset = this.instrumentPreset()
    const stopAt = startAt + durationInSeconds + preset.release + 0.08
    const output = this.createOutputChain(startAt, preset)

    preset.voices.forEach((voice) => {
      this.trackPlaybackHandle(this.startOscillatorVoice({
        frequency: frequency * voice.ratio,
        startAt,
        durationInSeconds,
        stopAt,
        output,
        voice,
        vibrato: preset.vibrato
      }))
    })

    if (preset.noise) {
      this.trackPlaybackHandle(this.startNoiseVoice({
        startAt,
        durationInSeconds,
        stopAt,
        output,
        noise: preset.noise
      }))
    }
  }

  instrumentPreset() {
    const presets = {
      piano: {
        outputGain: 0.74,
        release: 0.2,
        filter: { type: "lowpass", frequency: 3600, q: 0.7 },
        voices: [
          { type: "triangle", ratio: 1, peak: 0.17, attack: 0.01, decay: 0.18, sustain: 0.016, release: 0.1, detune: 0 },
          { type: "sine", ratio: 2, peak: 0.045, attack: 0.01, decay: 0.14, sustain: 0.007, release: 0.08, detune: 2 }
        ]
      },
      flute: {
        outputGain: 0.48,
        release: 0.06,
        filter: { type: "lowpass", frequency: 3600, q: 0.5 },
        vibrato: { frequency: 4.6, depth: 2.5 },
        voices: [
          { type: "sine", ratio: 1, peak: 0.13, attack: 0.018, decay: 0.06, sustain: 0.028, release: 0.045, detune: 0 },
          { type: "triangle", ratio: 2, peak: 0.012, attack: 0.014, decay: 0.05, sustain: 0.003, release: 0.04, detune: 0 }
        ],
        noise: {
          peak: 0.006,
          attack: 0.008,
          decay: 0.06,
          release: 0.015,
          filter: { type: "highpass", frequency: 2600, q: 0.6 }
        }
      },
      clarinet: {
        outputGain: 0.78,
        release: 0.24,
        filter: { type: "lowpass", frequency: 2800, q: 1.1 },
        vibrato: { frequency: 4.8, depth: 5 },
        voices: [
          { partials: [0, 0.9, 0.02, 0.62, 0.01, 0.28, 0.01, 0.16], ratio: 1, peak: 0.18, attack: 0.045, decay: 0.12, sustain: 0.08, release: 0.16, detune: 0 },
          { partials: [0, 0.55, 0.01, 0.34, 0.01, 0.16], ratio: 1, peak: 0.06, attack: 0.03, decay: 0.1, sustain: 0.02, release: 0.12, detune: 6 }
        ]
      },
      guitar: {
        outputGain: 0.72,
        release: 0.16,
        filter: { type: "lowpass", frequency: 3200, q: 0.8 },
        voices: [
          { type: "triangle", ratio: 1, peak: 0.17, attack: 0.003, decay: 0.11, sustain: 0.01, release: 0.08, detune: 0 },
          { type: "sine", ratio: 2, peak: 0.03, attack: 0.003, decay: 0.08, sustain: 0.004, release: 0.06, detune: 1 }
        ]
      },
      organ: {
        outputGain: 0.72,
        release: 0.18,
        filter: { type: "lowpass", frequency: 2600, q: 0.6 },
        voices: [
          { partials: [0, 1, 0.42, 0.33, 0.19, 0.1], ratio: 1, peak: 0.12, attack: 0.02, decay: 0.04, sustain: 0.08, release: 0.1, detune: 0 },
          { type: "sine", ratio: 2, peak: 0.032, attack: 0.02, decay: 0.04, sustain: 0.02, release: 0.08, detune: 0 }
        ]
      }
    }

    return presets[this.instrumentValue] || presets.piano
  }

  createFilter(config, startAt) {
    const filter = this.audioContext.createBiquadFilter()
    filter.type = config.type
    filter.frequency.setValueAtTime(config.frequency, startAt)
    filter.Q.setValueAtTime(config.q || 0.0001, startAt)
    return filter
  }

  createOutputChain(startAt, preset) {
    const output = this.audioContext.createGain()
    output.gain.setValueAtTime(preset.outputGain, startAt)

    if (preset.filter) {
      const filter = this.createFilter(preset.filter, startAt)
      output.connect(filter)
      filter.connect(this.audioContext.destination)
    } else {
      output.connect(this.audioContext.destination)
    }

    return output
  }

  startOscillatorVoice({ frequency, startAt, durationInSeconds, stopAt, output, voice, vibrato }) {
    const oscillator = this.audioContext.createOscillator()
    const gain = this.audioContext.createGain()

    if (voice.partials) {
      oscillator.setPeriodicWave(this.periodicWaveFor(voice.partials))
    } else {
      oscillator.type = voice.type || "sine"
    }

    oscillator.frequency.setValueAtTime(frequency, startAt)
    oscillator.detune.setValueAtTime(voice.detune || 0, startAt)

    if (vibrato) {
      const lfo = this.audioContext.createOscillator()
      const lfoGain = this.audioContext.createGain()
      lfo.type = "sine"
      lfo.frequency.setValueAtTime(vibrato.frequency, startAt)
      lfoGain.gain.setValueAtTime(vibrato.depth, startAt)
      lfo.connect(lfoGain)
      lfoGain.connect(oscillator.detune)
      lfo.start(startAt)
      lfo.stop(stopAt)
    }

    gain.gain.setValueAtTime(0.0001, startAt)
    gain.gain.linearRampToValueAtTime(voice.peak, startAt + voice.attack)
    gain.gain.exponentialRampToValueAtTime(voice.sustain, startAt + voice.attack + voice.decay)
    gain.gain.exponentialRampToValueAtTime(0.0001, startAt + durationInSeconds + voice.release)

    oscillator.connect(gain)
    gain.connect(output)
    oscillator.start(startAt)
    oscillator.stop(stopAt)

    return oscillator
  }

  startNoiseVoice({ startAt, durationInSeconds, stopAt, output, noise }) {
    const source = this.audioContext.createBufferSource()
    const gain = this.audioContext.createGain()
    const filter = this.createFilter(noise.filter, startAt)

    source.buffer = this.noiseBuffer()
    source.loop = true

    gain.gain.setValueAtTime(0.0001, startAt)
    gain.gain.linearRampToValueAtTime(noise.peak, startAt + noise.attack)
    gain.gain.exponentialRampToValueAtTime(0.0001, startAt + [durationInSeconds, noise.decay].min + noise.release)

    source.connect(filter)
    filter.connect(gain)
    gain.connect(output)
    source.start(startAt)
    source.stop(stopAt)

    return source
  }

  noiseBuffer() {
    if (this.cachedNoiseBuffer) return this.cachedNoiseBuffer

    const length = this.audioContext.sampleRate * 2
    const buffer = this.audioContext.createBuffer(1, length, this.audioContext.sampleRate)
    const channelData = buffer.getChannelData(0)

    for (let index = 0; index < length; index += 1) {
      channelData[index] = (Math.random() * 2) - 1
    }

    this.cachedNoiseBuffer = buffer
    return buffer
  }

  periodicWaveFor(partials) {
    this.waveCache ||= {}
    const cacheKey = partials.join("-")
    if (this.waveCache[cacheKey]) return this.waveCache[cacheKey]

    const real = new Float32Array(partials.length)
    const imag = new Float32Array(partials.length)
    partials.forEach((partial, index) => {
      imag[index] = partial
    })

    this.waveCache[cacheKey] = this.audioContext.createPeriodicWave(real, imag)
    return this.waveCache[cacheKey]
  }

  setTriggersDisabled(disabled) {
    if (!this.element.isConnected) return

    this.triggerTargets.forEach((trigger) => {
      trigger.disabled = disabled
    })
  }

  sleep(durationInMilliseconds) {
    return new Promise((resolve) => setTimeout(resolve, durationInMilliseconds))
  }

  isPlaybackRequestCurrent(requestId) {
    return this.element.isConnected && this.audioState.playbackToken === requestId
  }

  startPlaybackRequest() {
    this.stopActivePlayback()
    this.audioState.playbackToken += 1
    this.audioState.lastPlayedSignature = this.exerciseSignatureValue
    return this.audioState.playbackToken
  }

  invalidatePlayback() {
    this.audioState.playbackToken += 1
    this.stopActivePlayback()
  }

  trackPlaybackHandle(handle) {
    if (handle && typeof handle.stop === "function") {
      this.audioState.activePlaybackHandles.push(handle)
    }

    return handle
  }

  stopActivePlayback() {
    this.audioState.activePlaybackHandles.forEach((handle) => {
      try {
        handle.stop(0)
      } catch (_error) {
      }
    })
    this.audioState.activePlaybackHandles = []
  }
}
