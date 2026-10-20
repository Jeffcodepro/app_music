import HarmonyPlayerController from "./harmony_player_controller"
import { audioDiagnostic } from "audio/exercise_piano"

// Reuse audio ownership, cancellation, fallback, readiness and answer guards.
// Legacy phrases retain quarter-note timing; voices-v1 uses explicit onsets.
export default class extends HarmonyPlayerController {
  static values = { autoPlay: Boolean, tempoBpm: { type: Number, default: 80 }, format: String, events: Array, voiceCount: Number, totalSteps: Number, bpmUnitSteps: Number }

  connect() {
    super.connect()
    if (this.autoPlayValue) {
      this.autoPlayValue = false
      this.autoPlayTimeout = window.setTimeout(() => {
        this.autoPlayTimeout = null
        if (this.element.isConnected) return this.playBlocked()
      }, 120)
    }
  }

  disconnect() {
    this.cancelAutoPlay()
    super.disconnect()
  }

  cancelAutoPlay() {
    if (this.autoPlayTimeout) window.clearTimeout(this.autoPlayTimeout)
    this.autoPlayTimeout = null
  }

  play(style) {
    this.cancelAutoPlay()
    return super.play(style)
  }

  stop() {
    this.cancelAutoPlay()
    super.stop()
  }

  validateMelody() {
    this.validateSequence()
    if (!Number.isFinite(this.tempoBpmValue) || this.tempoBpmValue !== 80 ||
        this.sequenceValue.length !== 4 || this.sequenceValue.some(n => n.pitches.length !== 1 || n.frequencies.length !== 1)) {
      throw new RangeError("Invalid melodic dictation")
    }
    return 60 / this.tempoBpmValue
  }

  async playSequenceWithSoundfont(player, _style, request) {
    if (this.formatValue) return this.playVoicedSoundfont(player, request)
    const beat = this.validateMelody()
    const context = await this.ensureToneAudioContext(true)
    if (!this.isPlaybackRequestCurrent(request)) return 0
    const startAt = context.currentTime + 0.05
    this.sequenceValue.forEach((note, i) => {
      this.scheduleBlockedSoundfontChord(player, note.pitches, startAt + i * beat, beat * 0.82, request)
    })
    return 0.05 + 4 * beat + 0.2
  }

  async playSequenceWithSynth(_style, request) {
    if (this.formatValue) return this.playVoicedSynth(request)
    const beat = this.validateMelody()
    this.audioContext = await this.ensureAudioContext()
    if (!this.isPlaybackRequestCurrent(request)) return 0
    const startAt = this.audioContext.currentTime + 0.05
    this.sequenceValue.forEach((note, i) => {
      this.scheduleBlockedSynthChord(note.frequencies, startAt + i * beat, beat * 0.82, request)
    })
    return 0.05 + 4 * beat + this.instrumentPreset().release + 0.2
  }

  validateVoicedEvents() {
    if (!['voices-v1','voices-v2'].includes(this.formatValue) || this.tempoBpmValue !== 80 || this.bpmUnitStepsValue !== 4 ||
        !Number.isInteger(this.voiceCountValue) || this.voiceCountValue < 1 || this.voiceCountValue > 4 ||
        ![16,32].includes(this.totalStepsValue) || !Array.isArray(this.eventsValue) || this.eventsValue.length < 4 || this.eventsValue.length > 64) throw new RangeError('Invalid voiced dictation')
    const lines = Array.from({length:this.voiceCountValue},()=>[])
    for (const event of this.eventsValue) {
      const voice = /^voice-([1-4])$/.exec(event.voice_id || '')
      const note = /^([CDEFGAB])([2-5])$/.exec(event.pitch || '')
      if (!voice || !note || +voice[1] > lines.length || !Number.isInteger(event.start_step) || !Number.isInteger(event.duration_steps) ||
          ![1,2,4].includes(event.duration_steps) || event.start_step < 0 || event.start_step+event.duration_steps > this.totalStepsValue) throw new RangeError('Invalid melodic event')
      const midi = 12*(+note[2]+1)+({C:0,D:2,E:4,F:5,G:7,A:9,B:11})[note[1]]
      const frequency = 440*2**((midi-69)/12)
      if(!Number.isFinite(event.frequency)||Math.abs(event.frequency-frequency)>.001)throw new RangeError('Invalid melodic frequency')
      lines[+voice[1]-1].push(event)
    }
    for (const line of lines) {
      let cursor=0
      for (const e of line.sort((a,b)=>a.start_step-b.start_step)) { if(e.start_step!==cursor)throw new RangeError('Incomplete voice');cursor+=e.duration_steps }
      if(cursor!==this.totalStepsValue)throw new RangeError('Incomplete voice')
    }
    return 60/this.tempoBpmValue/this.bpmUnitStepsValue
  }

  async playVoicedSoundfont(player, request) {
    const step = this.validateVoicedEvents()
    const context = await this.ensureToneAudioContext(true)
    if(!this.isPlaybackRequestCurrent(request))return 0
    const origin = context.currentTime + .05
    const options = this.soundfontPlaybackOptions(1)
    for(const e of this.eventsValue) {
      this.trackPlaybackHandle(player.play(this.normalizePitchForSoundfont(e.pitch), origin+e.start_step*step,
        {...options,gain:options.gain/this.voiceCountValue,duration:e.duration_steps*step*.82}),request)
    }
    audioDiagnostic(this,'soundfont',context,{format:this.formatValue,events:this.eventsValue.length,voices:this.voiceCountValue})
    return .05+this.totalStepsValue*step+Math.max(options.release||0,.2)+.2
  }

  async playVoicedSynth(request) {
    const step=this.validateVoicedEvents()
    this.audioContext=await this.ensureAudioContext()
    if(!this.isPlaybackRequestCurrent(request))return 0
    const origin=this.audioContext.currentTime+.05
    for(const e of this.eventsValue)this.scheduleTone(e.frequency,origin+e.start_step*step,e.duration_steps*step*.82,request,1/this.voiceCountValue)
    audioDiagnostic(this,'synth',this.audioContext,{format:this.formatValue,events:this.eventsValue.length,voices:this.voiceCountValue})
    return .05+this.totalStepsValue*step+this.instrumentPreset().release+.2
  }
}
