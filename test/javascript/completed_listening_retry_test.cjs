const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm')
const strip=p=>fs.readFileSync(p,'utf8').replace(/^import[^\n]*\n/gm,'')
for(const name of ['interval','harmony']){
 test(`${name}: a completed listening survives Turbo retry but not another assignment instrument or failed replay`,()=>{
  const window={},helper=strip('app/javascript/audio/exercise_piano.js').replace(/^export /gm,'')
  const source=strip(`app/javascript/controllers/${name}_player_controller.js`).replace('export default class extends Controller','class Player extends Controller')
  const Player=vm.runInNewContext(`${helper}\n${source}\nPlayer`,{Controller:class{},window,console:{warn(){},info(){}}})
  const id='12345678-1234-4234-8234-123456789abc'
  const make=(signature=id,instrument='piano')=>{
   const p=Object.create(Player.prototype)
   Object.assign(p,{element:{isConnected:true,dataset:{}},exerciseSignatureValue:signature,instrumentValue:instrument,sequenceValue:[],firstFrequencyValue:261,secondFrequencyValue:329,hasStatusTarget:false,triggerTargets:[],hasHintTarget:false,hasFeedbackTarget:false})
   p.initialize();p.instrumentValueChanged();p.connect();return p
  }
  const guard=p=>{let prevented=false;const status={value:''};p.guardAnswer({currentTarget:{form:{querySelector:()=>status}},preventDefault(){prevented=true}});return{prevented,status:status.value}}
  const first=make(),request=first.startPlaybackRequest();first.markPlaybackReady(request);assert.equal(guard(first).prevented,false);first.disconnect()
  const retry=make();assert.deepEqual(guard(retry),{prevented:false,status:'ready'})
  retry.disconnect();const other=make('12345678-1234-4234-8234-123456789abd');assert.equal(guard(other).prevented,true);other.disconnect()
  const timbre=make(id,'flute');assert.equal(guard(timbre).prevented,true);timbre.disconnect()
  const replay=make();assert.equal(guard(replay).prevented,false);const replayRequest=replay.startPlaybackRequest();assert.equal(guard(replay).prevented,true)
  replay.invalidatePlayback();replay.markPlaybackReady(replayRequest);assert.equal(guard(replay).prevented,true);replay.disconnect()
  assert.equal(guard(make()).prevented,true)
 })
}
