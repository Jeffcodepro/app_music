const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')
const vm=require('node:vm')
const strip = path=>fs.readFileSync(path,'utf8').replace(/^import[^\n]*\n/gm,'')
const helpers=strip('app/javascript/audio/exercise_piano.js').replace(/^export /gm,'')
const parent=strip('app/javascript/controllers/harmony_player_controller.js').replace('export default class extends Controller','class HarmonyPlayerController extends Controller')
const child=strip('app/javascript/controllers/melody_player_controller.js').replace('export default class extends HarmonyPlayerController','class MelodyPlayerController extends HarmonyPlayerController')
const Player=vm.runInNewContext(`${helpers}\n${parent}\n${child}\nMelodyPlayerController`,{Controller:class{},window:{},console:{warn(){},info(){}},setTimeout,clearTimeout})
function harness(){const p=Object.create(Player.prototype);Object.assign(p,{tempoBpmValue:80,sequenceValue:['C4','D4','E4','G4'].map((pitch,i)=>({pitches:[pitch],frequencies:[[261.625565,293.664768,329.627557,391.995436][i]]})),ensureToneAudioContext:async()=>({currentTime:10}),ensureAudioContext:async()=>({currentTime:10}),isPlaybackRequestCurrent:()=>true,instrumentPreset:()=>({release:0.2})});return p}
for(const engine of ['Soundfont','Synth'])test(`${engine}: one four-note pass and repeat use identical quarter-note timing`,async()=>{
 const p=harness(),calls=[]
 p.scheduleBlockedSoundfontChord=(_player,notes,time,duration)=>calls.push({notes,time,duration})
 p.scheduleBlockedSynthChord=(notes,time,duration)=>calls.push({notes,time,duration})
 const run=()=>engine==='Soundfont'?p.playSequenceWithSoundfont({},'blocked',1):p.playSequenceWithSynth('blocked',1)
 const duration=await run();assert.equal(calls.length,4);assert.deepEqual(calls.map(c=>c.time),[10.05,10.8,11.55,12.3]);assert(calls.every(c=>Math.abs(c.duration-0.615)<1e-9));assert(duration>=3.05)
 await run();assert.equal(calls.length,8)
 p.isPlaybackRequestCurrent=()=>false;await run();assert.equal(calls.length,8)
})
test('melody rejects invalid BPM, polyphony and incomplete phrases',()=>{for(const mutate of [p=>p.tempoBpmValue=NaN,p=>p.tempoBpmValue=0,p=>p.sequenceValue.pop(),p=>p.sequenceValue[0].pitches.push('E4')]){const p=harness();mutate(p);assert.throws(()=>p.validateMelody())}})
test('melody inherits the neutral answer guard and failed playback never submits',()=>{const p=harness();p.isPlaying=true;p.hasHintTarget=true;p.hintTarget={hidden:true};let prevented=0;p.guardAnswer({preventDefault(){prevented++}});assert.equal(prevented,1);assert.equal(p.hintTarget.hidden,false)})
for(const engine of ['Soundfont','Synth'])test(`${engine}: sample the running clock once so all four beats share one origin`,async()=>{
 const p=harness(),calls=[];let reads=0
 const context={get currentTime(){reads++;return 10+reads/100}}
 p.ensureToneAudioContext=async()=>context;p.ensureAudioContext=async()=>context
 p.scheduleBlockedSoundfontChord=(_player,notes,time)=>calls.push(time)
 p.scheduleBlockedSynthChord=(notes,time)=>calls.push(time)
 if(engine==='Soundfont')await p.playSequenceWithSoundfont({},'blocked',1);else await p.playSequenceWithSynth('blocked',1)
 assert.equal(reads,1)
 calls.forEach((time,i)=>assert(Math.abs(time-calls[0]-i*0.75)<1e-8))
})

function voicedHarness(count=4){
 const p=harness(),rhythm=[4,2,2,1,1,2,4]
 Object.assign(p,{instrumentValue:'piano',formatValue:'voices-v1',voiceCountValue:count,totalStepsValue:32,bpmUnitStepsValue:4,sequenceValue:[],eventsValue:[]})
 for(let voice=1;voice<=count;voice++){
  let cursor=0;for(const duration of [...rhythm,...rhythm]){
   const octave=6-voice,midi=12*(octave+1)
   p.eventsValue.push({voice_id:`voice-${voice}`,pitch:`C${octave}`,frequency:440*2**((midi-69)/12),start_step:cursor,duration_steps:duration});cursor+=duration
  }
 }
 return p
}
for(const engine of ['Soundfont','Synth'])for(const count of [1,2,3,4])test(`${engine}: ${count} timed voices share one origin, full phrase and divided gain`,async()=>{
 const p=voicedHarness(count),calls=[];let reads=0
 const context={get currentTime(){reads++;return 10+reads/100}}
 p.ensureToneAudioContext=async()=>context;p.ensureAudioContext=async()=>context
 p.trackPlaybackHandle=()=>{}
 p.scheduleTone=(frequency,time,duration,request,gain)=>calls.push({frequency,time,duration,gain})
 const player={play:(pitch,time,options)=>{calls.push({pitch,time,...options});return{stop(){}}}}
 const run=()=>engine==='Soundfont'?p.playSequenceWithSoundfont(player,'blocked',1):p.playSequenceWithSynth('blocked',1)
 const duration=await run();assert.equal(reads,1);assert.equal(calls.length,14*count);assert(duration>=6.25)
 const start=calls[0].time
 calls.forEach((call,i)=>{
  assert(Math.abs(call.time-start-p.eventsValue[i].start_step*.1875)<1e-8)
  assert(Math.abs(call.duration-p.eventsValue[i].duration_steps*.1875*.82)<1e-8)
  assert(Math.abs(call.gain-(engine==='Synth'?1:1.2)/count)<1e-8)
 })
 assert.equal(calls.filter(c=>c.time===start).length,count)
 await run();assert.equal(calls.length,28*count)
 p.isPlaybackRequestCurrent=()=>false;await run();assert.equal(calls.length,28*count)
})
test('timed melody rejects unknown formats missing voices overlaps invalid frequencies and incomplete bars',()=>{
 for(const mutate of [p=>p.formatValue='unknown',p=>p.tempoBpmValue=NaN,p=>p.voiceCountValue=5,p=>p.totalStepsValue=31,p=>p.bpmUnitStepsValue=8,
  p=>p.eventsValue.pop(),p=>p.eventsValue[0].duration_steps=.5,p=>p.eventsValue[1].start_step=0,p=>p.eventsValue[0].frequency=NaN,
  p=>p.eventsValue[0].frequency=440,p=>p.eventsValue[0].voice_id='voice-0',p=>p.eventsValue[0].pitch='C#5']){
  const p=voicedHarness();mutate(p);assert.throws(()=>p.validateVoicedEvents(),{name:'RangeError'})
 }
})
