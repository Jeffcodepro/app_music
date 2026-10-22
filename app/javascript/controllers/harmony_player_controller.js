import { Controller } from "@hotwired/stimulus"
import { pianoSoundfontOptions, instrumentSoundfontOptions, pianoSynthPreset, toneEnvelope, audioDiagnostic, SOUNDFONT_LOAD_TIMEOUT_MS, rememberCompletedListening, hasCompletedListening, forgetCompletedListening } from "audio/exercise_piano"

export default class extends Controller {
  static targets = ["trigger", "feedback", "hint", "status"]
  static values = {
    sequence: Array,
    exerciseSignature: String,
    instrument: String
  }

  initialize() {
    this.setupSharedAudioState()
    this.controllerId = this.buildControllerId()
    this.isPlaying = false
    this.lastStyle = "broken"
  }

  connect() {
    this.setupSharedAudioState()
    this.claimPlaybackChannel()
    this.lastStyle = this.defaultPlaybackStyle()
    this.preloadCurrentInstrument()
    if (hasCompletedListening(this)) this.setPlaybackStatus("Escuta concluída. Você pode responder.", "completed")
  }

  disconnect() {
    this.isPlaying = false
    this.releasePlaybackChannel()
  }

  instrumentValueChanged() {
    this.setupSharedAudioState()
    if (!this.element?.isConnected) return

    this.stop()
    this.claimPlaybackChannel()
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
    const style = this.playbackChannel().lastPlayedDigest === this.currentPlaybackDigest() ? this.lastStyle : this.defaultPlaybackStyle()
    return this.play(style)
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
    if (!this.isPlaying && (this.playbackChannel().lastPlayedDigest === this.currentPlaybackDigest() || hasCompletedListening(this))) {
      const status = event.currentTarget.form?.querySelector('[name="playback_status"]')
      if (status) status.value = "ready"
      return
    }

    event.preventDefault()
    if (this.hasHintTarget) this.hintTarget.hidden = false
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.hidden = false
    }
  }

  exerciseSignatureValueChanged(currentValue, previousValue) {
    if (!previousValue || currentValue === previousValue || !this.element?.isConnected) return

    this.stop()
    this.claimPlaybackChannel()
    this.lastStyle = this.defaultPlaybackStyle()
  }

  stop() {
    this.isPlaying = false
    this.setTriggersDisabled(false)
    this.invalidatePlayback()
    this.setPlaybackStatus("Pronto para ouvir", "ready")
  }

  setPlaybackStatus(message, state) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.dataset.state = state
  }

  async play(style) {
    if (this.isPlaying) return

    const resolvedStyle = this.resolvedStyle(style)
    const playbackRequest = this.startPlaybackRequest()
    this.isPlaying = true
    this.lastStyle = resolvedStyle
    this.setTriggersDisabled(true)
    this.setPlaybackStatus("Preparando áudio…", "loading")

    try {
      await this.activatePlaybackContexts()
      if (!this.isPlaybackRequestCurrent(playbackRequest)) return

      const totalDuration = await this.playSequence(resolvedStyle, playbackRequest)
      if (!this.isPlaybackRequestCurrent(playbackRequest)) return

      if (!Number.isFinite(totalDuration) || totalDuration <= 0) throw new RangeError("Invalid playback duration")
      this.setPlaybackStatus("Reproduzindo…", "playing")
      await this.sleep(totalDuration * 1000)
      this.markPlaybackReady(playbackRequest)
      if (this.isPlaybackRequestCurrent(playbackRequest)) this.setPlaybackStatus("Escuta concluída. Você pode responder.", "completed")
    } catch (error) {
      if (this.isPlaybackRequestCurrent(playbackRequest)) {
        this.invalidatePlayback()
        this.isPlaying = false
        this.setTriggersDisabled(false)
        this.showPlaybackError()
        this.setPlaybackStatus("Áudio indisponível. Tente novamente.", "unavailable")
      }
      console.warn("Exercise audio could not be completed", error)
    } finally {
      if (this.isPlaybackRequestCurrent(playbackRequest)) {
        this.setTriggersDisabled(false)
        this.isPlaying = false
      }
    }
  }

  async activatePlaybackContexts() {
    await this.ensureAudioContext()
    if (!this.canUseSoundfont()) return

    try {
      await this.ensureToneAudioContext(true)
    } catch (error) {
      console.warn("Tone audio context activation failed, keeping synth fallback.", error)
    }
  }

  async playSequence(style, playbackRequest) {
    const player = await this.waitForSoundfontPlayer(SOUNDFONT_LOAD_TIMEOUT_MS)
    if (!this.isPlaybackRequestCurrent(playbackRequest)) return 0
    if (player) {
      try {
        return await this.playSequenceWithSoundfont(player, style, playbackRequest)
      } catch (error) {
        if (!this.isPlaybackRequestCurrent(playbackRequest)) return 0
        this.stopActivePlayback(this.playbackChannel())
        audioDiagnostic(this, "fallback", null, { reason: "sample-playback-failed" })
        console.warn("Soundfont playback failed, falling back to synth.", error)
      }
    }

    if (!player) audioDiagnostic(this, "fallback", null, { reason: "soundfont-unavailable-or-timeout" })
    return this.playSequenceWithSynth(style, playbackRequest)
  }

  async playSequenceWithSoundfont(player, style, playbackRequest) {
    this.validateSequence()
    const audioContext = await this.ensureToneAudioContext(true)
    if (!this.isPlaybackRequestCurrent(playbackRequest)) return 0

    const noteDuration = style === "blocked" ? 1.2 : 0.52
    const noteGap = style === "blocked" ? 0 : 0.13
    const chordGap = style === "blocked" ? 0.4 : 0.24
    let cursor = audioContext.currentTime + 0.05

    audioDiagnostic(this, "soundfont", audioContext, { style,
      optionsByChord: this.sequenceValue.map(chord => this.soundfontPlaybackOptions(style === "blocked" ? chord.pitches.length : 1)),
      sequence: this.sequenceValue.map(c => c.pitches) })
    this.sequenceValue.forEach((chord) => {
      if (style === "blocked") {
        this.scheduleBlockedSoundfontChord(player, chord.pitches, cursor, noteDuration, playbackRequest)
        cursor += noteDuration + chordGap
      } else {
        cursor += this.scheduleBrokenSoundfontChord(player, chord.pitches, cursor, noteDuration, noteGap, playbackRequest) + chordGap
      }
    })

    return (cursor - audioContext.currentTime) + 0.14
  }

  scheduleBlockedSoundfontChord(player, pitches, startAt, durationInSeconds, playbackRequest) {
    pitches.forEach((pitch) => {
      this.trackPlaybackHandle(player.play(this.normalizePitchForSoundfont(pitch), startAt, {
        duration: durationInSeconds,
        ...this.soundfontPlaybackOptions(pitches.length)
      }), playbackRequest)
    })
  }

  scheduleBrokenSoundfontChord(player, pitches, startAt, durationInSeconds, noteGap, playbackRequest) {
    let cursor = startAt

    pitches.forEach((pitch) => {
      this.trackPlaybackHandle(player.play(this.normalizePitchForSoundfont(pitch), cursor, {
        duration: durationInSeconds,
        ...this.soundfontPlaybackOptions()
      }), playbackRequest)
      cursor += durationInSeconds + noteGap
    })

    return cursor - startAt
  }

  async playSequenceWithSynth(style, playbackRequest) {
    this.validateSequence()
    this.audioContext = await this.ensureAudioContext()
    if (!this.isPlaybackRequestCurrent(playbackRequest)) return 0

    const preset = this.instrumentPreset()
    const chordDuration = style === "blocked" ? 1.15 : 0.58
    const noteGap = style === "blocked" ? 0 : 0.15
    const chordGap = style === "blocked" ? 0.4 : 0.28
    let cursor = this.audioContext.currentTime + 0.04

    audioDiagnostic(this, "synth", this.audioContext, { style, preset,
      gainScalesByChord: this.sequenceValue.map(chord => style === "blocked" && this.instrumentValue === "piano" ? 1 / Math.sqrt(chord.frequencies.length) : 1),
      sequence: this.sequenceValue.map(c => c.frequencies) })
    this.sequenceValue.forEach((chord) => {
      if (style === "blocked") {
        this.scheduleBlockedSynthChord(chord.frequencies, cursor, chordDuration, playbackRequest)
        cursor += chordDuration + chordGap
      } else {
        cursor += this.scheduleBrokenSynthChord(chord.frequencies, cursor, chordDuration, noteGap, playbackRequest) + chordGap
      }
    })

    return (cursor - this.audioContext.currentTime) + preset.release + 0.14
  }

  scheduleBlockedSynthChord(frequencies, startAt, durationInSeconds, playbackRequest) {
    frequencies.forEach((frequency) => {
      this.scheduleTone(frequency, startAt, durationInSeconds, playbackRequest, this.instrumentValue === "piano" ? 1 / Math.sqrt(frequencies.length) : 1)
    })
  }

  scheduleBrokenSynthChord(frequencies, startAt, durationInSeconds, noteGap, playbackRequest) {
    let cursor = startAt

    frequencies.forEach((frequency) => {
      this.scheduleTone(frequency, cursor, durationInSeconds, playbackRequest)
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
    if (this.cacheState.soundfontPlayers[instrumentId]) {
      return this.cacheState.soundfontPlayers[instrumentId]
    }

    if (!this.cacheState.soundfontPromises[instrumentId]) {
      this.cacheState.soundfontPromises[instrumentId] = this.loadSoundfontInstrument(instrumentId)
    }

    return this.cacheState.soundfontPromises[instrumentId]
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

      audioDiagnostic(this, "soundfont-loaded", audioContext, { soundfont: "MusyngKite", loadedProgram: player.name })
      this.cacheState.soundfontPlayers[instrumentId] = player
      delete this.cacheState.soundfontPromises[instrumentId]
      return player
    } catch (error) {
      delete this.cacheState.soundfontPromises[instrumentId]
      throw error
    }
  }

  soundfontProgramName(instrumentId = this.instrumentValue) {
    const mappings = {
      piano: "acoustic_grand_piano",
      flute: "flute",
      clarinet: "clarinet",
      guitar: "acoustic_guitar_nylon",
      organ: "church_organ"
    }

    return mappings[instrumentId] || mappings.piano
  }

  soundfontPlaybackOptions(voices = 1) {
    return instrumentSoundfontOptions(this.instrumentValue, this.soundfontGain(), voices)
  }

  soundfontGain() {
    if (this.instrumentValue === "piano") return pianoSoundfontOptions().gain
    const gains = {
      flute: 1.18,
      clarinet: 1.2,
      guitar: 1.28,
      organ: 1.16
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
    if (!this.cacheState.synthContext || this.cacheState.synthContext.state === "closed") {
      const AudioContext = window.AudioContext || window.webkitAudioContext
      this.cacheState.synthContext = new AudioContext()
    }

    if (this.cacheState.synthContext.state === "suspended") {
      await this.cacheState.synthContext.resume()
    }

    return this.cacheState.synthContext
  }

  scheduleTone(frequency, startAt, durationInSeconds, playbackRequest, gainScale = 1) {
    const preset = this.instrumentPreset()
    const stopAt = startAt + durationInSeconds + preset.release + 0.08
    const output = this.createOutputChain(startAt, preset, gainScale)

    preset.voices.forEach((voice) => {
      this.trackPlaybackHandle(this.startOscillatorVoice({
        frequency: frequency * voice.ratio,
        startAt,
        durationInSeconds,
        stopAt,
        output,
        voice,
        vibrato: preset.vibrato
      }), playbackRequest)
    })

    if (preset.noise) {
      this.trackPlaybackHandle(this.startNoiseVoice({
        startAt,
        durationInSeconds,
        stopAt,
        output,
        noise: preset.noise
      }), playbackRequest)
    }
  }

  validateSequence() {
    if (!this.sequenceValue?.length || !this.sequenceValue.every(chord =>
      Array.isArray(chord.pitches) && Array.isArray(chord.frequencies) &&
      chord.pitches.length > 0 && chord.pitches.length === chord.frequencies.length &&
      chord.frequencies.every(f => Number.isFinite(f) && f > 0 && f <= 20000))) {
      throw new RangeError("Invalid chord audio sequence")
    }
  }

  instrumentPreset() {
    const presets = {
      piano: pianoSynthPreset(),
      flute: {
        outputGain: 0.62,
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
        outputGain: 0.94,
        release: 0.24,
        filter: { type: "lowpass", frequency: 2800, q: 1.1 },
        vibrato: { frequency: 4.8, depth: 5 },
        voices: [
          { partials: [0, 0.9, 0.02, 0.62, 0.01, 0.28, 0.01, 0.16], ratio: 1, peak: 0.18, attack: 0.045, decay: 0.12, sustain: 0.08, release: 0.16, detune: 0 },
          { partials: [0, 0.55, 0.01, 0.34, 0.01, 0.16], ratio: 1, peak: 0.06, attack: 0.03, decay: 0.1, sustain: 0.02, release: 0.12, detune: 6 }
        ]
      },
      guitar: {
        outputGain: 0.86,
        release: 0.16,
        filter: { type: "lowpass", frequency: 3200, q: 0.8 },
        voices: [
          { type: "triangle", ratio: 1, peak: 0.17, attack: 0.003, decay: 0.11, sustain: 0.01, release: 0.08, detune: 0 },
          { type: "sine", ratio: 2, peak: 0.03, attack: 0.003, decay: 0.08, sustain: 0.004, release: 0.06, detune: 1 }
        ]
      },
      organ: {
        outputGain: 0.84,
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

  createOutputChain(startAt, preset, gainScale = 1) {
    const output = this.audioContext.createGain()
    output.gain.setValueAtTime(preset.outputGain * gainScale, startAt)

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
    const { attackEnd, decayEnd, releaseEnd } = toneEnvelope({ frequency, startAt, durationInSeconds, stopAt, voice })
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
    gain.gain.linearRampToValueAtTime(voice.peak, attackEnd)
    gain.gain.exponentialRampToValueAtTime(voice.sustain, decayEnd)
    gain.gain.exponentialRampToValueAtTime(0.0001, releaseEnd)

    oscillator.connect(gain)
    gain.connect(output)
    oscillator.start(startAt)
    oscillator.stop(stopAt)

    return oscillator
  }

  startNoiseVoice({ startAt, durationInSeconds, stopAt, output, noise }) {
    const values = [startAt, durationInSeconds, stopAt, noise.attack, noise.decay, noise.release]
    if (!values.every(Number.isFinite) || startAt < 0 || durationInSeconds <= 0 ||
        stopAt <= startAt || [noise.attack, noise.decay, noise.release].some((value) => value < 0)) {
      throw new RangeError("Invalid noise envelope timing")
    }
    const attackEnd = startAt + Math.min(noise.attack, durationInSeconds)
    const releaseEnd = startAt + Math.max(Math.min(durationInSeconds, noise.decay), attackEnd - startAt) + noise.release
    if (releaseEnd > stopAt) throw new RangeError("Noise envelope exceeds its stop time")

    const source = this.audioContext.createBufferSource()
    const gain = this.audioContext.createGain()
    const filter = this.createFilter(noise.filter, startAt)

    source.buffer = this.noiseBuffer()
    source.loop = true

    gain.gain.setValueAtTime(0.0001, startAt)
    gain.gain.linearRampToValueAtTime(noise.peak, attackEnd)
    gain.gain.exponentialRampToValueAtTime(0.0001, releaseEnd)

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

  isPlaybackRequestCurrent(playbackRequest) {
    const channel = this.playbackChannel()

    return this.element.isConnected &&
      channel.ownerId === this.controllerId &&
      channel.playbackToken === playbackRequest.token &&
      channel.currentDigest === playbackRequest.digest &&
      playbackRequest.exerciseSignature === this.exerciseSignatureValue &&
      playbackRequest.instrument === this.instrumentValue
  }

  startPlaybackRequest() {
    forgetCompletedListening(this)
    const channel = this.claimPlaybackChannel()
    this.stopActivePlayback(channel)
    channel.playbackToken += 1
    channel.currentDigest = this.currentPlaybackDigest()
    channel.lastPlayedDigest = null

    return {
      token: channel.playbackToken,
      digest: channel.currentDigest,
      exerciseSignature: this.exerciseSignatureValue,
      instrument: this.instrumentValue
    }
  }

  markPlaybackReady(playbackRequest) {
    if (!this.isPlaybackRequestCurrent(playbackRequest)) return

    this.playbackChannel().lastPlayedDigest = playbackRequest.digest
    rememberCompletedListening(this)
  }

  invalidatePlayback() {
    const channel = this.playbackChannel()
    if (channel.ownerId !== this.controllerId) return
    forgetCompletedListening(this)

    channel.playbackToken += 1
    channel.currentDigest = null
    channel.lastPlayedDigest = null
    this.stopActivePlayback(channel)
  }

  releasePlaybackChannel() {
    const channel = this.playbackChannel()
    if (channel.ownerId !== this.controllerId) return

    channel.playbackToken += 1
    channel.currentDigest = null
    channel.lastPlayedDigest = null
    this.stopActivePlayback(channel)
    channel.ownerId = null
  }

  trackPlaybackHandle(handle, playbackRequest) {
    if (!handle || typeof handle.stop !== "function") {
      throw new Error("Audio source did not start")
    }

    if (this.isPlaybackRequestCurrent(playbackRequest)) {
      this.playbackChannel().activePlaybackHandles.push(handle)
    } else {
      try {
        handle.stop(0)
      } catch (_error) {
      }
    }

    return handle
  }

  stopActivePlayback(channel = this.playbackChannel()) {
    channel.activePlaybackHandles.forEach((handle) => {
      try {
        handle.stop(0)
      } catch (_error) {
      }
    })
    channel.activePlaybackHandles = []
  }

  playbackChannel() {
    this.setupSharedAudioState()
    this.playbackState.channels.harmony ||= {
      ownerId: null,
      playbackToken: 0,
      currentDigest: null,
      lastPlayedDigest: null,
      activePlaybackHandles: []
    }

    return this.playbackState.channels.harmony
  }

  claimPlaybackChannel() {
    const channel = this.playbackChannel()

    if (channel.ownerId && channel.ownerId !== this.controllerId) {
      this.stopActivePlayback(channel)
    }

    channel.ownerId = this.controllerId
    return channel
  }

  currentPlaybackDigest() {
    return `${this.exerciseSignatureValue || "unknown"}|${this.instrumentValue || "piano"}|${(this.sequenceValue || []).length}`
  }

  buildControllerId() {
    return `harmony-player-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  }

  setupSharedAudioState() {
    const sharedCache = window.__appMusicAudioCache ||= {}
    this.cacheState = sharedCache.harmony ||= {}
    this.cacheState.soundfontPlayers ||= {}
    this.cacheState.soundfontPromises ||= {}
    this.cacheState.synthContext ||= null
    this.playbackState = window.__appMusicPlayback ||= { channels: {} }
  }
}
