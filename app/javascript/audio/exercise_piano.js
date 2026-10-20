// Keep the sampled transient; its recording already contains the piano decay.
export const SOUNDFONT_LOAD_TIMEOUT_MS = 10000

function listeningKey(controller) {
  const id = controller.exerciseSignatureValue
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id || '')) return null
  return controller.currentPlaybackDigest()
}

export function rememberCompletedListening(controller) {
  const key = listeningKey(controller)
  if (!key) return
  const completed = window.__appMusicCompletedListenings ||= new Map()
  completed.delete(key)
  completed.set(key, true)
  while (completed.size > 128) completed.delete(completed.keys().next().value)
}

export function hasCompletedListening(controller) {
  const key = listeningKey(controller)
  return Boolean(key && window.__appMusicCompletedListenings?.has(key))
}

export function forgetCompletedListening(controller) {
  const key = listeningKey(controller)
  if (key) window.__appMusicCompletedListenings?.delete(key)
}

export function pianoSoundfontOptions(voices = 1) {
  if (!Number.isInteger(voices) || voices < 1 || voices > 4) throw new RangeError("Invalid piano polyphony")
  return { gain: 1.2 / Math.sqrt(voices), attack: 0.0015, decay: 0.005, sustain: 1, release: 0.1 }
}

export function instrumentSoundfontOptions(instrument, gain, voices = 1) {
  if (!Number.isInteger(voices) || voices < 1 || voices > 4) throw new RangeError('Invalid sampled polyphony')
  if (instrument === 'piano') return pianoSoundfontOptions(voices)
  return { gain: gain / voices, attack: 0.0015, decay: 0.005, sustain: 1, release: 0.1 }
}

// An intelligible contingency instrument, not a substitute for sampled piano.
export function pianoSynthPreset() {
  return {
    outputGain: 0.8, release: 0.2,
    filter: { type: "lowpass", frequency: 8500, q: 0.5 },
    voices: [
      { partials: [0, 1, 0.45, 0.18, 0.09, 0.04], ratio: 1, peak: 0.19, attack: 0.003, decay: 0.5, sustain: 0.018, release: 0.1, detune: 0 },
      { partials: [0, 0, 0.5, 0.35, 0.2, 0.12, 0.05], ratio: 1, peak: 0.055, attack: 0.0015, decay: 0.09, sustain: 0.0001, release: 0.06, detune: 0 }
    ]
  }
}

export function toneEnvelope({ frequency, startAt, durationInSeconds, stopAt, voice }) {
  const values = [frequency, startAt, durationInSeconds, stopAt, voice.peak, voice.sustain, voice.attack, voice.decay, voice.release, voice.detune ?? 0]
  if (!values.every(Number.isFinite) || frequency <= 0 || startAt < 0 || durationInSeconds <= 0 ||
      voice.peak <= 0 || voice.sustain <= 0 || voice.sustain > voice.peak ||
      [voice.attack, voice.decay, voice.release].some(v => v < 0)) throw new RangeError("Invalid tone envelope")
  const attackEnd = startAt + Math.min(voice.attack, durationInSeconds)
  const decayEnd = Math.min(attackEnd + voice.decay, startAt + durationInSeconds)
  const releaseEnd = startAt + durationInSeconds + voice.release
  if (releaseEnd > stopAt) throw new RangeError("Tone envelope exceeds its stop time")
  return { attackEnd, decayEnd, releaseEnd }
}

export function audioDiagnostic(controller, engine, context, details = {}) {
  if (['soundfont', 'synth'].includes(engine)) {
    const quality = controller.element?.querySelector?.('[data-audio-quality]')
    if (quality) quality.hidden = engine !== 'synth'
  }
  if (controller.element?.dataset.audioDiagnostics !== "true") return
  const entry = { engine, instrument: controller.instrumentValue, program: controller.soundfontProgramName(),
    sampleRate: context?.sampleRate, ...details }
  const history = window.__appMusicAudioDiagnostics ||= []
  history.push(entry)
  if (history.length > 50) history.shift()
  console.info("[AppMusic audio]", entry)
}
