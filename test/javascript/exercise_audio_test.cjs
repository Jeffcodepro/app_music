const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')

function controller(name) {
  const source = fs.readFileSync(`app/javascript/controllers/${name}_controller.js`, 'utf8')
    .replace(/^import[^\n]*\n/gm, '')
    .replace('export default class extends Controller', 'class AuditedController extends Controller')
  const helpers = fs.readFileSync("app/javascript/audio/exercise_piano.js", "utf8").replace(/^export /gm, "")
  return vm.runInNewContext(`${helpers}\n${source}\nAuditedController`, { Controller: class {}, RangeError, console: { warn() {} }, setTimeout, clearTimeout,
    window: { setTimeout, clearTimeout } })
}

test('harmony noise envelope schedules finite monotonic times', () => {
  const Klass = controller('harmony_player')
  for (const duration of [0.001, 0.03, 0.6, 1.2]) {
    const times = []
    const node = { connect() {}, start() {}, stop() {} }
    const gain = { connect() {}, gain: {
      setValueAtTime(_v, t) { times.push(t) },
      linearRampToValueAtTime(_v, t) { times.push(t) },
      exponentialRampToValueAtTime(_v, t) { times.push(t) }
    } }
    const target = { audioContext: { createBufferSource: () => ({ ...node }), createGain: () => gain },
      createFilter: () => node, noiseBuffer: () => ({}) }
    Klass.prototype.startNoiseVoice.call(target, { startAt: 1, durationInSeconds: duration, stopAt: 3,
      output: {}, noise: { filter: {}, peak: 0.006, attack: 0.008, decay: 0.06, release: 0.015 } })
    assert(times.every(Number.isFinite))
    assert(times.every((t, i) => i === 0 || t >= times[i - 1]))
  }
})

test('harmony refuses invalid noise timing before scheduling nodes', () => {
  const Klass = controller('harmony_player')
  for (const duration of [NaN, Infinity, -1, 0]) {
    assert.throws(() => Klass.prototype.startNoiseVoice.call({}, { startAt: 1, durationInSeconds: duration,
      stopAt: 3, output: {}, noise: { attack: 0.008, decay: 0.06, release: 0.015 } }), RangeError)
  }
})

for (const name of ['interval_player', 'harmony_player', 'rhythm_player']) {
  test(`${name}: only completed playback allows submitting a response`, async () => {
    const Klass = controller(name)
    let finish
    let ready = false
    const target = Object.create(Klass.prototype)
    Object.assign(target, {
      isPlaying: false, exerciseSignatureValue: 'assignment', audioState: { lastPlayedSignature: null },
      hasStatusTarget: true, statusTarget: { textContent: '', dataset: {} },
      startPlaybackRequest: () => 1, isPlaybackRequestCurrent: () => true,
      setTriggersDisabled() {}, activatePlaybackContexts: async () => {},
      playWithBestAvailable: async () => 0.01, playSequence: async () => 0.01,
      performPlayback: async () => 0.01, resolvedStyle: () => 'broken',
      markPlaybackReady() { ready = true },
      sleep: () => new Promise((resolve) => { finish = resolve })
    })
    const playing = target.play('broken')
    await new Promise((resolve) => setImmediate(resolve))
    assert.equal(ready, false)
    assert.equal(target.statusTarget.dataset.state, 'playing')
    assert.equal(target.audioState.lastPlayedSignature, null)
    finish()
    await playing
    assert.equal(name === 'rhythm_player' ? target.audioState.lastPlayedSignature === 'assignment' : ready, true)
    assert.equal(target.isPlaying, false)
    assert.equal(target.statusTarget.dataset.state, 'completed')
  })

  test(`${name}: failed audio produces neutral feedback and keeps answers locked`, async () => {
    const Klass = controller(name)
    let ready = false
    let neutral = false
    let controlsDisabled = false
    const target = Object.create(Klass.prototype)
    const fail = async () => { throw new Error('Audio unavailable') }
    Object.assign(target, {
      isPlaying: false, audioState: { lastPlayedSignature: null }, startPlaybackRequest: () => 1,
      hasStatusTarget: true, statusTarget: { textContent: '', dataset: {} },
      isPlaybackRequestCurrent: () => true, setTriggersDisabled(value) { controlsDisabled = value },
      activatePlaybackContexts: fail, performPlayback: fail, resolvedStyle: () => 'broken',
      markPlaybackReady() { ready = true }, invalidatePlayback() {}, showPlaybackError() { neutral = true }
    })
    await target.play('broken')
    assert.equal(ready, false)
    assert.equal(neutral, true)
    assert.equal(controlsDisabled, false)
    assert.equal(target.isPlaying, false)
    assert.equal(target.audioState.lastPlayedSignature, null)
    assert.equal(target.statusTarget.dataset.state, 'unavailable')
  })

  test(`${name}: a cancelled playback cannot display a completed listening state`, async () => {
    const Klass = controller(name)
    const target = Object.create(Klass.prototype)
    let current = true, finish
    Object.assign(target, {
      isPlaying: false, hasStatusTarget: true, statusTarget: { textContent: '', dataset: {} },
      exerciseSignatureValue: 'old-assignment', audioState: { lastPlayedSignature: null },
      startPlaybackRequest: () => 1, isPlaybackRequestCurrent: () => current,
      setTriggersDisabled() {}, activatePlaybackContexts: async () => {},
      playWithBestAvailable: async () => 0.01, playSequence: async () => 0.01,
      performPlayback: async () => 0.01, resolvedStyle: () => 'broken',
      markPlaybackReady() { if (current) assert.fail('cancelled playback became ready') },
      sleep: () => new Promise(resolve => { finish = resolve })
    })
    const playback = target.play('broken')
    assert.equal(target.statusTarget.dataset.state, 'loading')
    await new Promise(resolve => setImmediate(resolve))
    current = false
    finish()
    await playback
    assert.notEqual(target.statusTarget.dataset.state, 'completed')
    assert.equal(target.audioState.lastPlayedSignature, null)
  })
}

test('both synths reject nonfinite, negative or out-of-bounds envelopes before creating nodes', () => {
  for (const name of ['interval_player', 'harmony_player']) {
    const Klass = controller(name)
    const valid = { startAt: 1, durationInSeconds: 0.5, stopAt: 2, output: {},
      noise: { attack: 0.01, decay: 0.06, release: 0.015 } }
    for (const change of [{startAt: NaN}, {stopAt: Infinity}, {stopAt: 1.001},
      {noise: {...valid.noise, attack: -1}}, {noise: {...valid.noise, decay: NaN}}]) {
      assert.throws(() => Klass.prototype.startNoiseVoice.call({}, {...valid, ...change}), RangeError)
    }
  }
})

test('ascending and descending intervals retain pitch order in soundfont and synth playback', async () => {
  const Klass = controller('interval_player')
  for (const [first, second, f1, f2] of [['C4', 'E4', 261.626, 329.628], ['E4', 'A3', 329.628, 220]]) {
    const scheduled = []
    const target = Object.create(Klass.prototype)
    Object.assign(target, {
      firstPitchValue: first, secondPitchValue: second, firstFrequencyValue: f1, secondFrequencyValue: f2,
      ensureToneAudioContext: async () => ({ currentTime: 10 }), ensureAudioContext: async () => ({ currentTime: 10 }),
      isPlaybackRequestCurrent: () => true, instrumentPreset: () => ({ noteDuration: 0.5, noteGap: 0.2 }),
      soundfontGain: () => 1, normalizePitchForSoundfont: (pitch) => pitch, trackPlaybackHandle() {},
      scheduleTone(frequency, startAt) { scheduled.push([frequency, startAt]); return 0.6 }
    })
    await target.playWithSoundfont({ play(pitch, startAt) { scheduled.push([pitch, startAt]); return {} } }, 1)
    assert.deepEqual(scheduled.map(([pitch]) => pitch), [first, second])
    assert(scheduled[1][1] > scheduled[0][1])
    scheduled.length = 0
    await target.playWithSynth(1)
    assert.deepEqual(scheduled.map(([frequency]) => frequency), [f1, f2])
    assert(scheduled[1][1] > scheduled[0][1])
  }
})

for (const name of ['interval_player', 'harmony_player']) {
  test(`${name}: rejected soundfont loading uses the synth fallback`, async () => {
    const Klass = controller(name)
    const target = Object.create(Klass.prototype)
    let usedSynth = 0
    const synth = async () => { usedSynth += 1; return 0.8 }
    Object.assign(target, {
      canUseSoundfont: () => true,
      soundfontInstrument: async () => { throw new Error('CDN unavailable') },
      isPlaybackRequestCurrent: () => true, playWithSynth: synth, playSequenceWithSynth: synth
    })
    const duration = name === 'interval_player' ? await target.playWithBestAvailable(1) : await target.playSequence('blocked', 1)
    assert.equal(duration, 0.8)
    assert.equal(usedSynth, 1)
  })
}

test('interval soundfont normalization preserves enharmonic octave crossings and rejects invalid MIDI', () => {
  const Klass = controller('interval_player')
  const target = Object.create(Klass.prototype)
  for (const [written, sounding] of [['B#3', 'C4'], ['Cb4', 'B3'], ['E#4', 'F4'], ['F♯4', 'F#4'], ['G♭4', 'F#4'], ['C##4', 'D4'], ['Dbb4', 'C4'], ['C𝄪4', 'D4'], ['D𝄫4', 'C4'], ['F♮4', 'F4']]) {
    assert.equal(target.normalizePitchForSoundfont(written), sounding)
  }
  for (const invalid of ['garbage', 'C4junk', 'C100000000000000000000', 'G#9', 'C-2', 'C###4']) {
    assert.throws(() => target.normalizePitchForSoundfont(invalid), RangeError)
  }
})

test('interval synth refuses invalid fundamental frequencies before creating any node', () => {
  const Klass = controller('interval_player')
  for (const frequency of [NaN, Infinity, -1, 0, 20001, '440']) {
    assert.throws(() => Klass.prototype.scheduleTone.call(Object.create(Klass.prototype), frequency, 1, 0.5, 1), RangeError)
  }
})

test('both interval playback paths reject invalid frequencies before opening audio contexts', async () => {
  const Klass = controller('interval_player')
  for (const method of ['playWithSoundfont', 'playWithSynth']) {
    const target = Object.create(Klass.prototype)
    Object.assign(target, { firstFrequencyValue: 440, secondFrequencyValue: NaN })
    await assert.rejects(() => target[method]({}, 1), RangeError)
  }
})
