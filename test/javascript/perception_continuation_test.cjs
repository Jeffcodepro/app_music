const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs')
const vm=require('node:vm')
const strip=path=>fs.readFileSync(path,'utf8').replace(/^import[^\n]*\n/gm,'')
function harness(kind,autoPlay=true){
  let next=1,plays=0;const timers=new Map()
  const window={setTimeout(callback){const id=next++;timers.set(id,callback);return id},clearTimeout(id){timers.delete(id)}}
  const helper=strip('app/javascript/audio/exercise_piano.js').replace(/^export /gm,'')
  const source=kind==='melody'?
    strip('app/javascript/controllers/harmony_player_controller.js').replace('export default class extends Controller','class HarmonyPlayerController extends Controller')+'\n'+strip('app/javascript/controllers/melody_player_controller.js').replace('export default class extends HarmonyPlayerController','class Player extends HarmonyPlayerController'):
    strip('app/javascript/controllers/interval_player_controller.js').replace('export default class extends Controller','class Player extends Controller')
  const Player=vm.runInNewContext(helper+'\n'+source+'\nPlayer',{Controller:class{},window,console:{warn(){},info(){}},setTimeout,clearTimeout})
  const p=Object.create(Player.prototype)
  Object.assign(p,{autoPlayValue:autoPlay,element:{isConnected:true},setupSharedAudioState(){},claimPlaybackChannel(){},releasePlaybackChannel(){},preloadCurrentInstrument(){},defaultPlaybackStyle:()=> 'blocked',resolvedStyle:()=> 'blocked',startPlaybackRequest:()=>({}),isPlaybackRequestCurrent:()=>true,activatePlaybackContexts:async()=>{plays++},playSequence:async()=>0.1,playWithBestAvailable:async()=>0.1,sleep:async()=>{},markPlaybackReady(){},setTriggersDisabled(){},setPlaybackStatus(){},invalidatePlayback(){}})
  return {p,timers,plays:()=>plays,fire:async()=>{for(const [id,callback]of[...timers]){timers.delete(id);await callback()}}}
}
for(const kind of ['interval','melody']){
 test(`${kind}: an explicit next action plays once and consumes autoplay for Turbo reconnect`,async()=>{const h=harness(kind);h.p.connect();assert.equal(h.p.autoPlayValue,false);assert.equal(h.timers.size,1);await h.fire();assert.equal(h.plays(),1);h.p.connect();await h.fire();assert.equal(h.plays(),1)})
 test(`${kind}: changing settings does not autoplay`,async()=>{const h=harness(kind,false);h.p.connect();await h.fire();assert.equal(h.plays(),0)})
 for(const action of ['stop','disconnect'])test(`${kind}: ${action} cancels a pending automatic playback`,async()=>{const h=harness(kind);h.p.connect();h.p[action]();await h.fire();assert.equal(h.plays(),0);assert.equal(h.timers.size,0)})
 test(`${kind}: manual play before the pending timer does not produce a second pass`,async()=>{const h=harness(kind);h.p.connect();await h.p.play();await h.fire();assert.equal(h.plays(),1)})
}
