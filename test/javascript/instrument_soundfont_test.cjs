const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm')
for(const kind of ['interval','harmony'])test(`${kind}: every instrument uses its sampled program without changing concert pitch`,async()=>{
 const helper=fs.readFileSync('app/javascript/audio/exercise_piano.js','utf8').replace(/^export /gm,'')
 const source=fs.readFileSync(`app/javascript/controllers/${kind}_player_controller.js`,'utf8').replace(/^import[^\n]*\n/gm,'').replace('export default class extends Controller','class Player extends Controller')
 const window={Soundfont:{async instrument(context,program,options){return{name:program,options}}}}
 const Player=vm.runInNewContext(`${helper}\n${source}\nPlayer`,{Controller:class{},window})
 for(const [id,program]of Object.entries({piano:'acoustic_grand_piano',flute:'flute',clarinet:'clarinet',guitar:'acoustic_guitar_nylon',organ:'church_organ'})){
  const p=Object.create(Player.prototype);Object.assign(p,{instrumentValue:id,element:{dataset:{}},cacheState:{soundfontPlayers:{},soundfontPromises:{}},ensureToneAudioContext:async()=>({})})
  const player=await p.loadSoundfontInstrument(id)
  assert.equal(player.name,program);assert.equal(player.options.soundfont,'MusyngKite');assert.equal(player.options.format,'mp3')
  assert.equal(await p.soundfontInstrument(),player)
  assert.equal(p.normalizePitchForSoundfont('C4'),'C4')
  const solo=p.soundfontPlaybackOptions(1),chord=p.soundfontPlaybackOptions(4)
  assert(solo.attack<=.003&&solo.sustain===1&&solo.release<=.12)
  assert(chord.gain<=solo.gain/(id==='piano'?2:4))
 }
})
