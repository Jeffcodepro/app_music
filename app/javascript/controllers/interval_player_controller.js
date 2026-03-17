import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "feedback"]
  static values = {
    firstFrequency: Number,
    secondFrequency: Number,
    firstPitch: String,
    secondPitch: String,
    autoPlay: Boolean,
    instrument: String
  }

  connect() {
    this.audioState = window.__appMusicAudio ||= {
      soundfontPlayers: {},
      soundfontPromises: {},
      synthContext: null
    }
    this.isPlaying = false
    this.preloadCurrentInstrument()
    if (this.autoPlayValue) {
      window.setTimeout(() => this.play(), 120)
    }
  }

  disconnect() {
    this.isPlaying = false
  }

  instrumentValueChanged() {
    this.preloadCurrentInstrument()
  }

  async play() {
    if (this.isPlaying) return

    this.isPlaying = true
    this.setTriggersDisabled(true)

    try {
      const totalDuration = await this.playWithBestAvailable()

      await this.sleep(totalDuration * 1000)
    } finally {
      this.setTriggersDisabled(false)
      this.isPlaying = false
    }
  }

  repeat() {
    return this.play()
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

  async playWithBestAvailable() {
    const player = await this.waitForSoundfontPlayer(2200)
    if (player) return this.playWithSoundfont(player)

    return this.playWithSynth()
  }

  async playWithSynth() {
    this.audioContext = await this.ensureAudioContext()
    const preset = this.instrumentPreset()
    const noteDuration = preset.noteDuration || this.noteDuration()
    const gapInSeconds = preset.noteGap || 0.28
    const startAt = this.audioContext.currentTime + 0.04

    return this.playIntervalSequence({
      firstFrequency: this.firstFrequencyValue,
      secondFrequency: this.secondFrequencyValue,
      startAt,
      noteDuration,
      gapInSeconds
    })
  }

  async playWithSoundfont(player) {
    const audioContext = await this.ensureToneAudioContext(true)
    const preset = this.instrumentPreset()
    const noteDuration = preset.noteDuration || this.noteDuration()
    const gapInSeconds = preset.noteGap || 0.28
    const startAt = audioContext.currentTime + 0.05
    const secondStartAt = startAt + noteDuration + gapInSeconds
    const firstPitch = this.normalizePitchForSoundfont(this.firstPitchValue)
    const secondPitch = this.normalizePitchForSoundfont(this.secondPitchValue)

    player.play(firstPitch, startAt, {
      duration: noteDuration,
      gain: this.soundfontGain()
    })

    player.play(secondPitch, secondStartAt, {
      duration: noteDuration,
      gain: this.soundfontGain()
    })

    return (secondStartAt - startAt) + noteDuration + 0.12
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
      piano: 1.15,
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
    const accidentalOffset = [...rawAccidental].reduce((total, accidental) => {
      return total + (accidental === "#" ? 1 : -1)
    }, 0)
    const chromaticScale = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    const baseIndex = semitoneOffsets[rawNote.toUpperCase()]
    let noteIndex = baseIndex + accidentalOffset
    let octave = Number.parseInt(rawOctave, 10)

    while (noteIndex < 0) {
      noteIndex += 12
      octave -= 1
    }

    while (noteIndex >= 12) {
      noteIndex -= 12
      octave += 1
    }

    return `${chromaticScale[noteIndex]}${octave}`
  }

  playIntervalSequence({ firstFrequency, secondFrequency, startAt, noteDuration, gapInSeconds }) {
    this.scheduleTone(firstFrequency, startAt, noteDuration)
    const secondStartAt = startAt + noteDuration + gapInSeconds
    const secondToneLength = this.scheduleTone(secondFrequency, secondStartAt, noteDuration)

    return (secondStartAt - startAt) + secondToneLength
  }

  scheduleTone(frequency, startAt, durationInSeconds) {
    const preset = this.instrumentPreset()
    const stopAt = startAt + durationInSeconds + preset.release + 0.08
    const output = this.createOutputChain(startAt, preset)

    preset.voices.forEach((voice) => {
      this.startOscillatorVoice({
        frequency: frequency * voice.ratio,
        startAt,
        durationInSeconds,
        stopAt,
        output,
        voice,
        vibrato: preset.vibrato
      })
    })

    if (preset.noise) {
      this.startNoiseVoice({
        startAt,
        durationInSeconds,
        stopAt,
        output,
        noise: preset.noise
      })
    }

    return stopAt - startAt
  }

  setTriggersDisabled(disabled) {
    this.triggerTargets.forEach((trigger) => {
      trigger.disabled = disabled
    })
  }

  sleep(durationInMilliseconds) {
    return new Promise((resolve) => setTimeout(resolve, durationInMilliseconds))
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
        noteDuration: 0.5,
        noteGap: 0.5,
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
  }

  noteDuration() {
    return 0.95
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
}
