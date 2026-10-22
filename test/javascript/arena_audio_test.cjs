const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm')
const source=fs.readFileSync('app/javascript/controllers/arena_audio_controller.js','utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Audio extends Controller')
function harness({failed=false,network=false}={}) {
  const calls=[];let played=0
  const Audio=vm.runInNewContext(`${source}\nAudio`,{Controller:class{},AbortController,Date,Error,Math,JSON,setTimeout,setInterval:()=>1,clearInterval(){},window:{},document:{querySelector:()=>({content:'csrf'})},fetch:async(url,o)=>{calls.push([url,JSON.parse(o.body)]);if(network)throw Error('offline');return{ok:true,status:url==='/complete'?204:200,json:async()=>({token:'server-token',minimum_seconds:0,replay:false})}}})
  const audio=new Audio();audio.startUrlValue='/start';audio.completeUrlValue='/complete';audio.generationValue=3;audio.playerValue='interval-player';audio.triggerTarget={disabled:false,textContent:'Tocar'};audio.statusTarget={dataset:{},textContent:''};audio.application={getControllerForElementAndIdentifier:()=>({activatePlaybackContexts:async()=>{},play:async()=>{played++;audio.statusTarget.dataset.state=failed?'unavailable':'completed'}})};audio.connect()
  return{audio,calls,get played(){return played}}
}
test('completion receipt follows real player completion and carries no answer or client timing',async()=>{const h=harness();await h.audio.play();assert.equal(h.played,1);assert.equal(h.calls.length,2);assert.deepEqual(h.calls[1][1],{generation:3,token:'server-token'});assert.equal(h.audio.triggerTarget.disabled,false)})
test('failed sound produces no receipt or knowledge error and can retry',async()=>{const h=harness({failed:true});await h.audio.play();assert.equal(h.calls.length,1);assert.equal(h.audio.statusTarget.dataset.state,'unavailable');assert.match(h.audio.statusTarget.textContent,/Nenhuma resposta/);assert.equal(h.audio.triggerTarget.disabled,false)})
test('network failure never starts audio or submits an answer',async()=>{const h=harness({network:true});await h.audio.play();assert.equal(h.played,0);assert.equal(h.calls.length,1);h.audio.disconnect();assert.equal(h.audio.abort.signal.aborted,true)})

test('scheduled listens announce before each play, run once, and never catch up missed audio in a burst', async()=>{
 let now=0; const window={__appMusicArenaAudioEnabled:true}
 class Clock extends Date { static now(){return now} }
 const Audio=vm.runInNewContext(`${source}\nAudio`,{Controller:class{},AbortController,Date:Clock,Error,Math,JSON,Set,window,setInterval:()=>1,clearInterval(){}})
 const a=new Audio();Object.assign(a,{policyValue:'sequence-v1',serverNowValue:new Date(0).toISOString(),repetitionsValue:3,triggerTarget:{},cueTarget:{textContent:''},hasCueTarget:true,element:{dataset:{}},slotsValue:[1,2,3].map(n=>({listen:n,cue_at:new Date(n*10000).toISOString(),play_at:new Date(n*10000+2000).toISOString(),cutoff_at:new Date(n*10000+4000).toISOString()}))})
 const plays=[];a.play=async index=>{plays.push(index)};a.connect()
 now=10000;a.tickSequence();assert.match(a.cueTarget.textContent,/Primeira escuta/);assert.equal(plays.length,0)
 now=12000;a.tickSequence();a.tickSequence();assert.deepEqual(plays,[1])
 now=20000;a.tickSequence();assert.match(a.cueTarget.textContent,/Segunda escuta/)
 now=22000;a.tickSequence();assert.deepEqual(plays,[1,2])
 now=35000;a.tickSequence();assert.deepEqual(plays,[1,2])
 a.disconnect();now=32000;a.tickSequence();assert.deepEqual(plays,[1,2])
})
test('scheduled audio requests one initial activation and skips already completed slots after reload',()=>{
 const window={};let now=0
 class Clock extends Date{static now(){return now}}
 const Audio=vm.runInNewContext(`${source}\nAudio`,{Controller:class{},AbortController,Date:Clock,Set,window,setInterval:()=>1,clearInterval(){}})
 const a=new Audio();Object.assign(a,{policyValue:'sequence-v1',serverNowValue:new Date(0).toISOString(),repetitionsValue:1,triggerTarget:{},slotsValue:[{listen:1,completed:true,cue_at:new Date(0).toISOString(),play_at:new Date(1000).toISOString(),cutoff_at:new Date(3000).toISOString()}]})
 let played=0;a.play=()=>played++;a.connect();assert.equal(a.triggerTarget.textContent,'Ativar áudio')
 window.__appMusicArenaAudioEnabled=true;now=2000;a.tickSequence();assert.equal(played,0);assert.equal(a.triggerTarget.hidden,true);a.disconnect()
})

test('one activation primes every player cache and keeps native fallback when Tone is unavailable',async()=>{
 const helper=fs.readFileSync('app/javascript/audio/arena_listening.js','utf8').replace(/^export /gm,'')
 let resumes=0,events=0
 class Context {constructor(){this.state='suspended'}async resume(){resumes++;this.state='running'}}
 const closed={state:'closed'},window={__appMusicAudioCache:{synthContext:closed},AudioContext:Context,Tone:{start:async()=>{throw Error('CDN unavailable')}},dispatchEvent(){events++}}
 const activate=vm.runInNewContext(`${helper}\nactivateArenaAudio`,{window,Set,Promise,Error,CustomEvent:class{}})
 await activate();assert.equal(resumes,1);assert.equal(events,1);assert.equal(window.__appMusicArenaAudioEnabled,true)
 assert.notEqual(window.__appMusicAudioCache.synthContext,closed)
 assert.equal(window.__appMusicAudioCache.harmony.synthContext,window.__appMusicAudio.synthContext)
 const audioHelper=fs.readFileSync('app/javascript/audio/exercise_piano.js','utf8').replace(/^export /gm,'')
 const harmony=fs.readFileSync('app/javascript/controllers/harmony_player_controller.js','utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Player extends Controller')
 const Player=vm.runInNewContext(`${audioHelper}\n${harmony}\nPlayer`,{Controller:class{},window})
 const p=Object.create(Player.prototype);p.setupSharedAudioState();assert(p.cacheState.soundfontPlayers);assert(p.cacheState.soundfontPromises)
})
