const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs'),vm=require('node:vm')
const source=fs.readFileSync('app/javascript/controllers/rhythm_player_controller.js','utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Player extends Controller')
const Player=vm.runInNewContext(source+'\nPlayer',{Controller:class{},window:{},console})
function harness(n,d,groups,kind,unit,bars=1,bpm=60){const p=Object.create(Player.prototype),clicks=[],hits=[];Object.assign(p,{hasMeterValue:true,meterValue:{numerator:n,denominator:d,groups,kind,bpm_unit_steps:unit},measureCountValue:bars,totalStepsValue:n*16/d*bars,tempoBpmValue:bpm,eventsValue:[{start_step:0,duration_steps:1}],metronomeDuringPatternValue:true,ensureAudioContext:async()=>({currentTime:10}),isPlaybackRequestCurrent:()=>true,scheduleMetronomeClick:(time,accented)=>clicks.push({time,accented}),scheduleRhythmHit:(time,duration,accented)=>hits.push({time,duration,accented})});return{p,clicks,hits}}
for(const [name,args,expected]of[
 ['3/4',[3,4,[1,1,1],'simple',4],[6.17,[10.05,11.05,12.05,13.05,14.05,15.05]]],
 ['6/8',[6,8,[3,3],'compound',6],[4.17,[10.05,11.05,12.05,13.05]]],
 ['2/2',[2,2,[1,1],'simple',8],[4.17,[10.05,11.05,12.05,13.05]]],
 ['6/4',[6,4,[3,3],'compound',12],[4.17,[10.05,11.05,12.05,13.05]]],
 ['6/16',[6,16,[3,3],'compound',3],[4.17,[10.05,11.05,12.05,13.05]]],
 ['2/4 two bars',[2,4,[1,1],'simple',4,2],[6.17,[10.05,11.05,12.05,13.05,14.05,15.05]]]
])test(`${name}: count-in, one whole phrase, rests and BPM unit have exact reference durations`,async()=>{const h=harness(...args);const duration=await h.p.performPlayback(1);assert(Math.abs(duration-expected[0])<1e-8);assert.deepEqual(h.clicks.map(c=>Number(c.time.toFixed(2))),expected[1]);assert.equal(h.hits.length,1);assert.equal(h.hits[0].time,args[0]===3?13.05:12.05)})
test('5/8 at eighth=120 accents the explicit 2+3 grouping',async()=>{const h=harness(5,8,[2,3],'additive',2,1,120);const duration=await h.p.performPlayback(1);assert(Math.abs(duration-5.17)<1e-8);assert.deepEqual(h.clicks.map(c=>c.accented),[true,false,true,false,false,true,false,true,false,false]);assert.deepEqual(h.clicks.slice(0,5).map(c=>Number((c.time-10.05).toFixed(2))),[0,.5,1,1.5,2])})
test('invalid meter or mismatched duration fails without scheduling any audio',async()=>{for(const mutate of [p=>p.meterValue.groups=[2,2],p=>p.meterValue.bpm_unit_steps=0,p=>p.totalStepsValue=100,p=>p.eventsValue[0].start_step=-1,p=>p.tempoBpmValue=Infinity]){const h=harness(6,8,[3,3],'compound',6);mutate(h.p);await assert.rejects(()=>h.p.performPlayback(1));assert.equal(h.hits.length,0);assert.equal(h.clicks.length,0)}})
test('changing a meter stops all scheduled audio and clears readiness before navigation',()=>{const h=harness(6,8,[3,3],'compound',6);let stopped=0;Object.assign(h.p,{audioState:{playbackToken:3,lastPlayedSignature:'old',activeRhythmNodes:[{stop(){stopped++}}]},isPlaying:true,triggerTargets:[{disabled:true}],setPlaybackStatus(){}});h.p.stop();assert.equal(stopped,1);assert.equal(h.p.isPlaying,false);assert.equal(h.p.audioState.lastPlayedSignature,null);assert.equal(h.p.triggerTargets[0].disabled,false);assert.equal(h.p.audioState.playbackToken,4)})
