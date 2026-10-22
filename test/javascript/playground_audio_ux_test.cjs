const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')

function load(name) {
  const helperPath = 'app/javascript/audio/exercise_piano.js'
  const helpers = fs.existsSync(helperPath) ? fs.readFileSync(helperPath, 'utf8').replace(/^export /gm, '') : ''
  const source = fs.readFileSync(`app/javascript/controllers/${name}_controller.js`, 'utf8')
    .replace(/^import[^\n]*\n/gm, '').replace('export default class extends Controller', 'class Player extends Controller')
  return vm.runInNewContext(`${helpers}\n${source}\nPlayer`, { Controller: class {}, RangeError,
    console: { warn() {}, info() {} }, window: { setTimeout, clearTimeout }, setTimeout, clearTimeout })
}

for (const name of ['interval_player', 'harmony_player']) {
  test(`${name}: a stale sample rejection cannot interrupt the next exercise`, async () => {
    const target = Object.create(load(name).prototype)
    let current = true
    const fail = async () => { current = false; throw Error('late rejection') }
    Object.assign(target, { waitForSoundfontPlayer: async () => ({}), isPlaybackRequestCurrent: () => current,
      playWithSoundfont: fail, playSequenceWithSoundfont: fail,
      stopActivePlayback() { assert.fail('must not stop the new owner') },
      playWithSynth() { assert.fail('must not restart stale playback') },
      playSequenceWithSynth() { assert.fail('must not restart stale playback') } })
    const duration = name === 'interval_player' ? await target.playWithBestAvailable({}) : await target.playSequence('blocked', {})
    assert.equal(duration, 0)
  })
  test(`${name}: answering before playback gives a neutral instruction without submitting`, () => {
    const target = Object.create(load(name).prototype)
    Object.assign(target, { isPlaying: true, hasHintTarget: true, hintTarget: { hidden: true } })
    let prevented = false
    target.guardAnswer({ preventDefault() { prevented = true } })
    assert.equal(prevented, true)
    assert.equal(target.hintTarget.hidden, false)
  })
  test(`${name}: missing samples are failures and changing the exercise cancels scheduled notes`, () => {
    const target = Object.create(load(name).prototype)
    const channel = { activePlaybackHandles: [], playbackToken: 1, currentDigest: 'old', lastPlayedDigest: 'old' }
    target.playbackChannel = () => channel
    target.isPlaybackRequestCurrent = () => true
    assert.throws(() => target.trackPlaybackHandle(undefined, {}), /did not start/)
    let stopped = 0
    target.trackPlaybackHandle({ stop() { stopped++ } }, {})
    target.invalidatePlayback()
    assert.equal(stopped, 1)
    assert.equal(channel.lastPlayedDigest, null)
    assert.equal(channel.activePlaybackHandles.length, 0)
  })

  test(`${name}: successful loading caches the selected program and repeat reuses it`, async () => {
    const target = Object.create(load(name).prototype)
    let loaded = 0
    Object.assign(target, { instrumentValue: 'piano', cacheState: { soundfontPlayers: {}, soundfontPromises: {} },
      async loadSoundfontInstrument(id) { loaded++; const player = { name: this.soundfontProgramName(id) }; this.cacheState.soundfontPlayers[id] = player; return player } })
    const first = await target.soundfontInstrument()
    assert.equal(first.name, 'acoustic_grand_piano')
    assert.equal(await target.soundfontInstrument(), first)
    assert.equal(loaded, 1)
    let played = 0
    target.play = () => { played++ }
    target.playbackChannel = () => ({ lastPlayedDigest: null })
    target.currentPlaybackDigest = () => 'exercise'
    target.repeat()
    target.repeat()
    assert.equal(played, 2)
  })
  test(`${name}: a failed partial sample sequence stops its notes before fallback`, async () => {
    const target = Object.create(load(name).prototype)
    const calls = []
    Object.assign(target, { instrumentValue: 'piano', element: { dataset: {} },
      waitForSoundfontPlayer: async () => ({}), isPlaybackRequestCurrent: () => true,
      playWithSoundfont: async () => { throw Error('missing sample') },
      playSequenceWithSoundfont: async () => { throw Error('missing sample') },
      playbackChannel: () => ({}), stopActivePlayback() { calls.push('stop') },
      playWithSynth: () => calls.push('synth'), playSequenceWithSynth: () => calls.push('synth') })
    await (name === 'interval_player' ? target.playWithBestAvailable({}) : target.playSequence('blocked', {}))
    assert.deepEqual(calls, ['stop', 'synth'])
  })

  test(`${name}: piano keeps the sampled attack and reserves gain headroom`, () => {
    const target = Object.create(load(name).prototype)
    target.instrumentValue = 'piano'
    const options = target.soundfontPlaybackOptions(4)
    assert(options.attack > 0 && options.attack < 0.003)
    assert.equal(options.sustain, 1)
    assert(options.release <= 0.12)
    assert(options.gain > 0 && options.gain <= 0.6)
    const preset = target.instrumentPreset()
    assert(preset.filter.frequency >= 8000)
    assert(preset.voices.every(v => v.detune === 0))
  })

  test(`${name}: oscillator envelopes reject nonfinite values and fit short notes`, () => {
    const target = Object.create(load(name).prototype)
    const times = []
    const node = { connect() {}, start() {}, stop() {}, frequency: { setValueAtTime() {} }, detune: { setValueAtTime() {} } }
    const parameter = { setValueAtTime(_v,t) { times.push(t) }, linearRampToValueAtTime(_v,t) { times.push(t) }, exponentialRampToValueAtTime(_v,t) { times.push(t) } }
    target.audioContext = { createOscillator: () => ({ ...node }), createGain: () => ({ connect() {}, gain: parameter }) }
    const voice = { type: 'sine', peak: 0.2, sustain: 0.01, attack: 0.01, decay: 0.3, release: 0.1 }
    const args = { frequency: 440, startAt: 1, durationInSeconds: 0.001, stopAt: 1.2, output: {}, voice }
    target.startOscillatorVoice(args)
    assert(times.every(Number.isFinite))
    assert(times.every((t,i) => i === 0 || t >= times[i-1]))
    for (const change of [{ frequency: NaN }, { startAt: Infinity }, { durationInSeconds: -1 }, { voice: { ...voice, attack: NaN } }]) {
      assert.throws(() => target.startOscillatorVoice({ ...args, ...change }), RangeError)
    }
  })
}

test('interval readiness includes the scheduled lead-in and sampled release', async () => {
  const target = Object.create(load('interval_player').prototype)
  Object.assign(target, { instrumentValue: 'piano', firstPitchValue: 'C4', secondPitchValue: 'E4',
    firstFrequencyValue: 261.626, secondFrequencyValue: 329.628,
    ensureToneAudioContext: async () => ({ currentTime: 1 }), isPlaybackRequestCurrent: () => true,
    trackPlaybackHandle() {} })
  const duration = await target.playWithSoundfont({ play() { return { stop() {} } } }, {})
  assert(duration >= 0.05 + 0.95 + 0.28 + 0.95 + 0.1)
})

test('harmony preserves simultaneous chords, arpeggio order, durations and piano gain per texture', () => {
  const target = Object.create(load('harmony_player').prototype)
  target.instrumentValue = 'piano'
  target.trackPlaybackHandle = () => {}
  const calls = []
  const player = { play(pitch, at, opts) { calls.push({ pitch, at, ...opts }); return { stop() {} } } }
  target.scheduleBlockedSoundfontChord(player, ['C4','E4','G4','B4'], 1, 1.2, {})
  assert(calls.every(c => c.at === 1 && c.duration === 1.2 && c.gain === 0.6))
  calls.length = 0
  target.scheduleBrokenSoundfontChord(player, ['C4','E4','G4'], 1, 0.52, 0.13, {})
  assert.deepEqual(calls.map(c => c.pitch), ['C4','E4','G4'])
  assert.deepEqual(calls.map(c => c.at), [1, 1.65, 2.3])
  assert(calls.every(c => c.duration === 0.52 && c.gain === 1.2))
  const synth = []
  target.scheduleTone = (...args) => synth.push(args)
  target.scheduleBlockedSynthChord([261.626,329.628,391.995], 1, 1.15, {})
  assert(synth.every(c => c[1] === 1 && c[2] === 1.15 && c[4] <= 0.58))
})

test('harmony rejects invalid frequencies before opening either context', async () => {
  const target = Object.create(load('harmony_player').prototype)
  for (const frequency of [NaN, Infinity, 0, -440, 20001]) {
    target.sequenceValue = [{ pitches: ['A4'], frequencies: [frequency] }]
    await assert.rejects(target.playSequenceWithSynth('blocked', {}), RangeError)
    await assert.rejects(target.playSequenceWithSoundfont({}, 'blocked', {}), RangeError)
  }
})

test('rhythm plays one pass per action even for a legacy two-cycle assignment', async () => {
  const target = Object.create(load('rhythm_player').prototype)
  const hits = [], clicks = []
  Object.assign(target, { tempoBpmValue:120, countInBeatsValue:4, playbackCyclesValue:2,
    metronomeDuringPatternValue:false, eventsValue:[0,4,8,12].map(start_step=>({start_step,duration_steps:4})),
    ensureAudioContext:async()=>({currentTime:10}), isPlaybackRequestCurrent:()=>true,
    scheduleMetronomeClick:(time,accented)=>clicks.push({time,accented}),
    scheduleRhythmHit:(time,duration)=>hits.push({time,duration}) })
  const duration = await target.performPlayback(1)
  assert.equal(hits.length,4,'automatic playback must not repeat the pattern')
  assert.equal(clicks.length,4,'preserve the count-in')
  assert(Math.abs(duration-4.17)<1e-8)
  await target.performPlayback(2)
  assert.equal(hits.length,8,'a second explicit action repeats exactly one pass')
  assert.equal(clicks.filter(c=>c.accented).length,2)
})
